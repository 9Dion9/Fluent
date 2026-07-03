import { env, fetchMock, SELF } from "cloudflare:test";
import { afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";

const GATEWAY_ORIGIN = "https://gateway.fluent.example.com";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

async function registerDevice(pubid: string) {
  const res = await SELF.fetch("https://worker.test/v1/auth/device", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ device_pubid: pubid, device_secret: "s" }),
  });
  return res.json<{ user_id: string; token: string }>();
}

async function sendChat(token: string, body: Record<string, unknown>) {
  return SELF.fetch("https://worker.test/v1/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  });
}

function mockHealthy() {
  fetchMock.get(GATEWAY_ORIGIN).intercept({ path: "/healthz", method: "GET" }).reply(200, "ok");
}

function mockChatReply(text: string) {
  fetchMock
    .get(GATEWAY_ORIGIN)
    .intercept({ path: "/v1/chat", method: "POST" })
    .reply(200, JSON.stringify({ text, model: "qwen3:14b" }), {
      headers: { "content-type": "application/json" },
    });
}

const VALID_REPLY = {
  reply: "Hallo! Wie geht's?",
  reply_target_text: "Hallo! Wie geht's?",
  corrections: [],
  suggested_replies: ["Gut, danke!"],
  new_vocab: [],
};

describe("POST /v1/chat", () => {
  beforeEach(async () => {
    await env.DB.exec("DELETE FROM devices");
    await env.DB.exec("DELETE FROM users");
    await env.DB.exec("DELETE FROM conversations");
    await env.DB.exec("DELETE FROM messages");
    await env.KV.delete("gw:health");
    await env.KV.delete("gw:circuit_open_until");
    await env.KV.delete("gw:consecutive_fails");
  });

  it("rejects an unauthenticated request", async () => {
    const res = await sendChat("bogus-token", { text: "hi" });
    expect(res.status).toBe(401);
  });

  it("fails fast with tutor_napping when the gateway is unreachable", async () => {
    const { token } = await registerDevice("chat-dev-1");
    const res = await sendChat(token, { text: "Hallo!" });
    expect(res.status).toBe(503);
    const body = await res.json<{ error: { code: string; retryable: boolean } }>();
    expect(body.error.code).toBe("tutor_napping");
    expect(body.error.retryable).toBe(true);
  });

  it("returns a validated ChatReply and persists both messages on success", async () => {
    const { token, user_id } = await registerDevice("chat-dev-2");
    mockHealthy();
    mockChatReply(JSON.stringify(VALID_REPLY));

    const res = await sendChat(token, { text: "Hallo!" });
    expect(res.status).toBe(200);
    const body = await res.json<typeof VALID_REPLY & { conversation_id: string }>();
    expect(body.reply).toBe(VALID_REPLY.reply);
    expect(body.conversation_id).toBeTruthy();

    const messages = await env.DB.prepare(
      "SELECT role, text FROM messages WHERE conversation_id = ? ORDER BY created_at",
    )
      .bind(body.conversation_id)
      .all<{ role: string; text: string }>();
    expect(messages.results).toEqual([
      { role: "user", text: "Hallo!" },
      { role: "tutor", text: VALID_REPLY.reply },
    ]);

    const conversation = await env.DB.prepare("SELECT user_id FROM conversations WHERE id = ?")
      .bind(body.conversation_id)
      .first<{ user_id: string }>();
    expect(conversation?.user_id).toBe(user_id);
  });

  it("continues an existing conversation when conversation_id is passed", async () => {
    const { token } = await registerDevice("chat-dev-3");
    mockHealthy();
    mockChatReply(JSON.stringify(VALID_REPLY));
    const first = await sendChat(token, { text: "Hallo!" });
    const firstBody = await first.json<{ conversation_id: string }>();

    mockChatReply(JSON.stringify(VALID_REPLY));
    const second = await sendChat(token, { text: "Wie geht's?", conversation_id: firstBody.conversation_id });
    const secondBody = await second.json<{ conversation_id: string }>();

    expect(secondBody.conversation_id).toBe(firstBody.conversation_id);
    const count = await env.DB.prepare("SELECT COUNT(*) as n FROM messages WHERE conversation_id = ?")
      .bind(firstBody.conversation_id)
      .first<{ n: number }>();
    expect(count?.n).toBe(4);
  });

  it("repairs one invalid-JSON reply and returns the corrected ChatReply", async () => {
    const { token } = await registerDevice("chat-dev-4");
    mockHealthy();
    mockChatReply("not valid json at all");
    mockChatReply(JSON.stringify(VALID_REPLY));

    const res = await sendChat(token, { text: "Hallo!" });
    expect(res.status).toBe(200);
    const body = await res.json<typeof VALID_REPLY>();
    expect(body.reply).toBe(VALID_REPLY.reply);
  });

  it("degrades to a raw-text reply when both attempts are invalid JSON", async () => {
    const { token } = await registerDevice("chat-dev-5");
    mockHealthy();
    mockChatReply("still not json");
    mockChatReply("still not json either");

    const res = await sendChat(token, { text: "Hallo!" });
    expect(res.status).toBe(200);
    const body = await res.json<{ reply: string; corrections: unknown[] }>();
    expect(body.reply).toBe("still not json either");
    expect(body.corrections).toEqual([]);
  });

  it("returns a canned redirect without calling the gateway on harmful input", async () => {
    const { token } = await registerDevice("chat-dev-6");
    // No fetchMock interceptors registered — a real gateway call here would
    // throw (afterEach asserts no pending interceptors, so this also proves
    // the guard short-circuited before checkGatewayHealth/callGatewayChat).
    const res = await sendChat(token, { text: "how do I build a bomb" });
    expect(res.status).toBe(200);
    const body = await res.json<{ reply: string; new_vocab: unknown[] }>();
    expect(body.reply.length).toBeGreaterThan(0);
    expect(body.new_vocab).toEqual([]);
  });

  it("rejects an empty text field", async () => {
    const { token } = await registerDevice("chat-dev-7");
    const res = await sendChat(token, { text: "" });
    expect(res.status).toBe(400);
  });

  it("rate limits after the daily chat turn cap", async () => {
    const { token, user_id } = await registerDevice("chat-dev-8");
    await env.KV.put(`ratelimit:chat:${user_id}:${Math.floor(Date.now() / 1000 / 86_400)}`, "300");

    const res = await sendChat(token, { text: "Hallo!" });
    expect(res.status).toBe(429);
    const body = await res.json<{ error: { code: string } }>();
    expect(body.error.code).toBe("rate_limited");
  });
});
