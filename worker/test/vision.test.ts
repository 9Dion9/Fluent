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

async function registerAndAuth(pubid: string) {
  const authRes = await SELF.fetch("https://worker.test/v1/auth/device", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ device_pubid: pubid, device_secret: "s" }),
  });
  const { token } = await authRes.json<{ user_id: string; token: string }>();

  await SELF.fetch("https://worker.test/v1/profile", {
    method: "PUT",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      native_lang: "en",
      target_lang: "de",
      level: "beginner",
      interests: ["travel"],
      tutor_name: "Emma",
      tutor_persona: "sunny",
      tz: "Europe/Berlin",
      daily_goal: 10,
    }),
  });
  return token;
}

async function insertWordWithLabel(label: string) {
  const wordId = crypto.randomUUID();
  await env.DB.prepare(
    "INSERT INTO content_words (id, lang, word, translation, pos, gender, cefr, topics_json, source, verified) VALUES (?, 'de', 'die Tasse', 'cup', 'noun', 'die', 'A1', '[]', 'pipeline', 1)",
  )
    .bind(wordId)
    .run();
  await env.DB.prepare("INSERT INTO vision_labels (label, lang, word_id) VALUES (?, 'de', ?)").bind(label, wordId).run();
  return wordId;
}

function mockHealthy() {
  fetchMock.get(GATEWAY_ORIGIN).intercept({ path: "/healthz", method: "GET" }).reply(200, "ok");
}

function mockVisionCall(body: Record<string, unknown>) {
  fetchMock
    .get(GATEWAY_ORIGIN)
    .intercept({ path: "/v1/vision", method: "POST" })
    .reply(200, JSON.stringify(body), { headers: { "content-type": "application/json" } });
}

async function identify(token: string, body: Record<string, unknown>) {
  return SELF.fetch("https://worker.test/v1/vision/identify", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  });
}

describe("POST /v1/vision/identify", () => {
  beforeEach(async () => {
    await env.DB.exec("DELETE FROM devices");
    await env.DB.exec("DELETE FROM users");
    await env.DB.exec("DELETE FROM user_cards");
    await env.DB.exec("DELETE FROM srs_state");
    await env.DB.exec("DELETE FROM vision_labels");
    await env.DB.exec("DELETE FROM content_words");
    await env.KV.delete("gw:health");
    await env.KV.delete("gw:circuit_open_until");
    await env.KV.delete("gw:consecutive_fails");
  });

  it("rejects an unauthenticated request", async () => {
    const res = await SELF.fetch("https://worker.test/v1/vision/identify", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ detected_label: "cup" }),
    });
    expect(res.status).toBe(401);
  });

  it("rejects a body with neither image nor label", async () => {
    const token = await registerAndAuth("vision-dev-1");
    const res = await identify(token, {});
    expect(res.status).toBe(400);
  });

  it("instant path: a known label resolves without touching the gateway", async () => {
    const token = await registerAndAuth("vision-dev-2");
    await insertWordWithLabel("coffee cup");

    const res = await identify(token, { detected_label: "Coffee Cup" }); // case-insensitive
    expect(res.status).toBe(200);
    const body = await res.json<{ word: string; source: string }>();
    expect(body.word).toBe("die Tasse");
    expect(body.source).toBe("pipeline");

    // snapped words auto-enter the deck (CLAUDE.md §9)
    const card = await env.DB.prepare("SELECT source FROM user_cards").first<{ source: string }>();
    expect(card?.source).toBe("camera");
  });

  it("404s an unknown label with no image (VLM fallback needs an image)", async () => {
    const token = await registerAndAuth("vision-dev-3");
    const res = await identify(token, { detected_label: "some unmapped thing" });
    expect(res.status).toBe(404);
  });

  it("falls back to the VLM when the label is unmapped and an image is provided", async () => {
    const token = await registerAndAuth("vision-dev-4");
    mockHealthy();
    mockVisionCall({ word: "der Stuhl", translation: "chair", pos: "noun", gender: "der", example: "Der Stuhl ist bequem." });

    const res = await identify(token, { image_b64: "aGVsbG8=", detected_label: "chair" });
    expect(res.status).toBe(200);
    const body = await res.json<{ word: string; source: string; verified: boolean }>();
    expect(body.word).toBe("der Stuhl");
    expect(body.source).toBe("camera_vlm");
    expect(body.verified).toBe(false); // not Wiktionary-checked (CLAUDE.md §3)

    // the label mapping is cached for next time (self-learning)
    const mapping = await env.DB.prepare("SELECT word_id FROM vision_labels WHERE label = 'chair'").first();
    expect(mapping).not.toBeNull();
  });

  it("maps gateway-down to tutor_napping", async () => {
    const token = await registerAndAuth("vision-dev-5");
    fetchMock.get(GATEWAY_ORIGIN).intercept({ path: "/healthz", method: "GET" }).reply(500, "down");

    const res = await identify(token, { image_b64: "aGVsbG8=" });
    expect(res.status).toBe(503);
    const body = await res.json<{ error: { code: string } }>();
    expect(body.error.code).toBe("tutor_napping");
  });
});
