import type { Env } from "../env";

export interface ConversationRow {
  id: string;
  user_id: string;
  scenario_id: string | null;
  created_at: number;
  summary: string | null;
  summarized_through_message_count: number;
}

export interface MessageRow {
  id: string;
  conversation_id: string;
  role: "user" | "tutor";
  text: string | null;
  audio_key: string | null;
  corrections_json: string | null;
  created_at: number;
}

export interface ScenarioRow {
  id: string;
  lang: string;
  title: string;
  emoji: string | null;
  min_level: string;
  seed_prompt: string;
  focus_word_ids_json: string | null;
}

/** Message count above which the Worker requests a cached summary (CLAUDE.md §7). */
export const SUMMARY_TRIGGER_TURNS = 40;
/** How many recent messages get sent verbatim as chat context (CLAUDE.md §7). */
export const CONTEXT_MESSAGE_LIMIT = 16;

export async function getOrCreateConversation(
  env: Env,
  userId: string,
  conversationId: string | undefined,
  scenarioId: string | undefined,
  now: number,
): Promise<ConversationRow> {
  if (conversationId) {
    const existing = await env.DB.prepare("SELECT * FROM conversations WHERE id = ? AND user_id = ?")
      .bind(conversationId, userId)
      .first<ConversationRow>();
    if (existing) return existing;
  }

  const id = crypto.randomUUID();
  await env.DB.prepare(
    "INSERT INTO conversations (id, user_id, scenario_id, created_at, summary, summarized_through_message_count) VALUES (?, ?, ?, ?, NULL, 0)",
  )
    .bind(id, userId, scenarioId ?? null, now)
    .run();

  return {
    id,
    user_id: userId,
    scenario_id: scenarioId ?? null,
    created_at: now,
    summary: null,
    summarized_through_message_count: 0,
  };
}

export async function getScenario(env: Env, scenarioId: string): Promise<ScenarioRow | null> {
  return env.DB.prepare("SELECT * FROM scenarios WHERE id = ?").bind(scenarioId).first<ScenarioRow>();
}

/** Scenario picker shelf (DESIGN.md §8) — filtered by lang + the user's level ceiling. */
export async function listScenarios(env: Env, lang: string, maxCefrs: string[]): Promise<ScenarioRow[]> {
  const placeholders = maxCefrs.map(() => "?").join(",");
  const { results } = await env.DB.prepare(
    `SELECT * FROM scenarios WHERE lang = ? AND min_level IN (${placeholders}) ORDER BY min_level ASC`,
  )
    .bind(lang, ...maxCefrs)
    .all<ScenarioRow>();
  return results;
}

export async function getRecentMessages(env: Env, conversationId: string, limit: number): Promise<MessageRow[]> {
  const { results } = await env.DB.prepare(
    "SELECT * FROM messages WHERE conversation_id = ? ORDER BY created_at DESC LIMIT ?",
  )
    .bind(conversationId, limit)
    .all<MessageRow>();
  return results.reverse();
}

export async function countMessages(env: Env, conversationId: string): Promise<number> {
  const row = await env.DB.prepare("SELECT COUNT(*) as n FROM messages WHERE conversation_id = ?")
    .bind(conversationId)
    .first<{ n: number }>();
  return row?.n ?? 0;
}

export async function insertMessage(
  env: Env,
  params: {
    conversationId: string;
    role: "user" | "tutor";
    text: string | null;
    correctionsJson: string | null;
    now: number;
  },
): Promise<void> {
  await env.DB.prepare(
    "INSERT INTO messages (id, conversation_id, role, text, audio_key, corrections_json, created_at) VALUES (?, ?, ?, ?, NULL, ?, ?)",
  )
    .bind(crypto.randomUUID(), params.conversationId, params.role, params.text, params.correctionsJson, params.now)
    .run();
}

export async function updateConversationSummary(
  env: Env,
  conversationId: string,
  summary: string,
  throughMessageCount: number,
): Promise<void> {
  await env.DB.prepare(
    "UPDATE conversations SET summary = ?, summarized_through_message_count = ? WHERE id = ?",
  )
    .bind(summary, throughMessageCount, conversationId)
    .run();
}
