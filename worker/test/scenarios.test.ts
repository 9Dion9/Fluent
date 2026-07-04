import { env, SELF } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";

async function registerAndAuth(pubid: string, level = "beginner") {
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
      level,
      interests: ["travel"],
      tutor_name: "Emma",
      tutor_persona: "sunny",
      tz: "Europe/Berlin",
      daily_goal: 10,
    }),
  });
  return token;
}

async function insertScenario(overrides: Partial<Record<string, unknown>> = {}) {
  const defaults = {
    id: crypto.randomUUID(),
    lang: "de",
    title: "Order a coffee",
    emoji: "☕",
    min_level: "A1",
    seed_prompt: "You are ordering a coffee at a German cafe.",
    focus_word_ids_json: JSON.stringify(["word-1"]),
    ...overrides,
  };
  await env.DB.prepare(
    "INSERT INTO scenarios (id, lang, title, emoji, min_level, seed_prompt, focus_word_ids_json) VALUES (?, ?, ?, ?, ?, ?, ?)",
  )
    .bind(defaults.id, defaults.lang, defaults.title, defaults.emoji, defaults.min_level, defaults.seed_prompt, defaults.focus_word_ids_json)
    .run();
  return defaults;
}

describe("GET /v1/scenarios", () => {
  beforeEach(async () => {
    await env.DB.exec("DELETE FROM devices");
    await env.DB.exec("DELETE FROM users");
    await env.DB.exec("DELETE FROM scenarios");
  });

  it("rejects an unauthenticated request", async () => {
    const res = await SELF.fetch("https://worker.test/v1/scenarios");
    expect(res.status).toBe(401);
  });

  it("returns scenarios matching the user's target language", async () => {
    const token = await registerAndAuth("scenario-dev-1");
    await insertScenario({ lang: "de", title: "Order a coffee" });
    await insertScenario({ lang: "en", title: "Wrong language" }); // must never come back

    const res = await SELF.fetch("https://worker.test/v1/scenarios", { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status).toBe(200);
    const body = await res.json<{ title: string; lang: string }[]>();
    expect(body).toHaveLength(1);
    expect(body[0]?.title).toBe("Order a coffee");
  });

  it("excludes scenarios above the user's level ceiling", async () => {
    const token = await registerAndAuth("scenario-dev-2", "beginner"); // ceiling = A2
    await insertScenario({ min_level: "A1", title: "Easy one" });
    await insertScenario({ min_level: "C1", title: "Too hard" });

    const res = await SELF.fetch("https://worker.test/v1/scenarios", { headers: { Authorization: `Bearer ${token}` } });
    const body = await res.json<{ title: string }[]>();
    expect(body.map((s) => s.title)).toEqual(["Easy one"]);
  });

  it("returns an empty array, not an error, when nothing matches", async () => {
    const token = await registerAndAuth("scenario-dev-3");
    const res = await SELF.fetch("https://worker.test/v1/scenarios", { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual([]);
  });
});
