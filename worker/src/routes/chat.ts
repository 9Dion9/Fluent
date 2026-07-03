import { Hono } from "hono";
import type { Env } from "../env";
import { AppError } from "../errors";
import { authenticate } from "../middleware/authenticate";
import { chatReplySchema, chatRequestSchema, type ChatReply } from "../schemas";
import { getUser } from "../repos/users";
import {
  CONTEXT_MESSAGE_LIMIT,
  SUMMARY_TRIGGER_TURNS,
  countMessages,
  getOrCreateConversation,
  getRecentMessages,
  getScenario,
  insertMessage,
  updateConversationSummary,
  type MessageRow,
} from "../repos/conversations";
import { buildRepairPrompt, buildSystemPrompt } from "../prompt";
import { guardCannedReply, guardPrefilterHit } from "../guard";
import { checkGatewayHealth, callGatewayChat, GatewayCallError } from "../gateway";
import { isRateLimited } from "../rateLimit";

export const chatRoute = new Hono<{ Bindings: Env }>();
chatRoute.use("*", authenticate);

const CHAT_TURNS_PER_DAY = 300; // CLAUDE.md §13
const CONTEXT_TOKEN_BUDGET = 3000;
const CHARS_PER_TOKEN_ESTIMATE = 4;

type GatewayMessage = { role: "system" | "user" | "assistant"; content: string };

chatRoute.post("/", async (c) => {
  const userId = c.get("userId") as string;
  const env = c.env;
  const now = Date.now();

  if (await isRateLimited(env, `chat:${userId}`, CHAT_TURNS_PER_DAY, 86_400)) {
    throw new AppError("rate_limited", "You've reached today's chat limit — back tomorrow!", {
      retryable: false,
    });
  }

  const parsed = chatRequestSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    throw new AppError("invalid_request", "Malformed chat request.");
  }
  const { conversation_id, scenario_id, text } = parsed.data;

  const user = await getUser(env, userId);
  if (!user) throw new AppError("unauthorized", "No such user.");

  const conversation = await getOrCreateConversation(env, userId, conversation_id, scenario_id, now);
  const scenario = conversation.scenario_id ? await getScenario(env, conversation.scenario_id) : null;

  // Guardrail layer 2 (CLAUDE.md §7): clearly harmful input never reaches the model.
  if (guardPrefilterHit(text)) {
    const reply = guardCannedReply(user.tutor_persona);
    await insertMessage(env, { conversationId: conversation.id, role: "user", text, correctionsJson: null, now });
    await insertMessage(env, {
      conversationId: conversation.id,
      role: "tutor",
      text: reply.reply,
      correctionsJson: null,
      now: now + 1,
    });
    return c.json({ ...reply, conversation_id: conversation.id });
  }

  const health = await checkGatewayHealth(env);
  if (health === "down") {
    throw new AppError("tutor_napping", `${user.tutor_name} is taking a quick nap — try again in a bit.`, {
      retryable: true,
    });
  }

  const messageCount = await countMessages(env, conversation.id);
  let summary = conversation.summary;
  if (messageCount > SUMMARY_TRIGGER_TURNS && conversation.summarized_through_message_count < messageCount) {
    summary = await requestSummary(env, conversation.id, messageCount);
  }

  const history = trimToTokenBudget(await getRecentMessages(env, conversation.id, CONTEXT_MESSAGE_LIMIT));
  const focusWords = scenario ? (JSON.parse(scenario.focus_word_ids_json ?? "[]") as string[]) : [];

  const systemPrompt = buildSystemPrompt({ user, focusWords, scenario, summary });
  const gatewayMessages: GatewayMessage[] = [
    { role: "system", content: systemPrompt },
    ...history.map((m): GatewayMessage => ({ role: m.role === "user" ? "user" : "assistant", content: m.text ?? "" })),
    { role: "user", content: text },
  ];

  const reply = await getValidatedReply(env, gatewayMessages);

  await insertMessage(env, { conversationId: conversation.id, role: "user", text, correctionsJson: null, now });
  await insertMessage(env, {
    conversationId: conversation.id,
    role: "tutor",
    text: reply.reply,
    correctionsJson: reply.corrections.length > 0 ? JSON.stringify(reply.corrections) : null,
    now: now + 1,
  });

  return c.json({ ...reply, conversation_id: conversation.id });
});

/**
 * Calls the gateway, validates against the ChatReply schema, and on invalid
 * JSON does exactly one repair round-trip before degrading to a raw-text
 * reply — CLAUDE.md §6: "the user never sees an error for a malformed model reply."
 */
async function getValidatedReply(env: Env, messages: GatewayMessage[]): Promise<ChatReply> {
  let raw: string;
  try {
    raw = await callGatewayChat(env, messages);
  } catch (err) {
    if (err instanceof GatewayCallError) {
      throw new AppError("tutor_napping", "Couldn't reach the tutor — try again in a bit.", { retryable: true });
    }
    throw err;
  }

  const firstAttempt = tryParseChatReply(raw);
  if (firstAttempt) return firstAttempt;

  let repaired: string;
  try {
    repaired = await callGatewayChat(env, [
      ...messages,
      { role: "assistant", content: raw },
      { role: "user", content: buildRepairPrompt("response was not valid JSON matching the ChatReply schema") },
    ]);
  } catch {
    return degradedReply(raw);
  }

  return tryParseChatReply(repaired) ?? degradedReply(repaired);
}

function tryParseChatReply(raw: string): ChatReply | null {
  try {
    const json = JSON.parse(raw);
    const result = chatReplySchema.safeParse(json);
    return result.success ? result.data : null;
  } catch {
    return null;
  }
}

function degradedReply(raw: string): ChatReply {
  return { reply: raw, reply_target_text: "", corrections: [], suggested_replies: [], new_vocab: [] };
}

function trimToTokenBudget(messages: MessageRow[]): MessageRow[] {
  let budget = CONTEXT_TOKEN_BUDGET;
  const kept: MessageRow[] = [];
  for (let i = messages.length - 1; i >= 0; i--) {
    const message = messages[i];
    if (!message) continue;
    const tokens = Math.ceil((message.text?.length ?? 0) / CHARS_PER_TOKEN_ESTIMATE);
    if (tokens > budget && kept.length > 0) break;
    kept.unshift(message);
    budget -= tokens;
  }
  return kept;
}

async function requestSummary(env: Env, conversationId: string, throughCount: number): Promise<string | null> {
  const history = await getRecentMessages(env, conversationId, 40);
  const transcript = history.map((m) => `${m.role}: ${m.text ?? ""}`).join("\n");
  try {
    const raw = await callGatewayChat(env, [
      {
        role: "system",
        content: "Summarize this language-learning conversation in exactly 3 sentences, focusing on topics discussed and the learner's demonstrated level. Respond with plain text only, no JSON.",
      },
      { role: "user", content: transcript },
    ]);
    await updateConversationSummary(env, conversationId, raw, throughCount);
    return raw;
  } catch {
    return null; // non-fatal — the conversation proceeds without a summary this turn
  }
}
