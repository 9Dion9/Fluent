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

async function insertQuiz(overrides: Partial<Record<string, unknown>> = {}) {
  const defaults = {
    id: crypto.randomUUID(),
    lang: "de",
    type: "mcq",
    prompt_json: JSON.stringify({ question: "Was bedeutet Tisch?", options: ["table", "chair", "door", "window"] }),
    answer_json: JSON.stringify({ correct_index: 0 }),
    difficulty: 1,
    word_ids_json: JSON.stringify(["word-1"]),
    content_hash: crypto.randomUUID(),
    ...overrides,
  };
  await env.DB.prepare(
    "INSERT INTO quizzes (id, lang, type, prompt_json, answer_json, difficulty, word_ids_json, content_hash) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
  )
    .bind(
      defaults.id,
      defaults.lang,
      defaults.type,
      defaults.prompt_json,
      defaults.answer_json,
      defaults.difficulty,
      defaults.word_ids_json,
      defaults.content_hash,
    )
    .run();
  return defaults;
}

describe("GET /v1/quiz/next", () => {
  beforeEach(async () => {
    await env.DB.exec("DELETE FROM devices");
    await env.DB.exec("DELETE FROM users");
    await env.DB.exec("DELETE FROM quizzes");
  });

  it("rejects an unauthenticated request", async () => {
    const res = await SELF.fetch("https://worker.test/v1/quiz/next");
    expect(res.status).toBe(401);
  });

  it("returns a quiz matching the user's target language", async () => {
    const token = await registerAndAuth("quiz-dev-1");
    await insertQuiz({ lang: "de", difficulty: 1 });
    await insertQuiz({ lang: "en", difficulty: 1 }); // wrong lang — must never come back

    const res = await SELF.fetch("https://worker.test/v1/quiz/next", { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status).toBe(200);
    const body = await res.json<{ lang: string; prompt: { question: string } }>();
    expect(body.lang).toBe("de");
    expect(body.prompt.question).toBe("Was bedeutet Tisch?");
  });

  it("filters by requested types", async () => {
    const token = await registerAndAuth("quiz-dev-2");
    await insertQuiz({ type: "mcq", difficulty: 1 });
    await insertQuiz({
      type: "order",
      prompt_json: JSON.stringify({ tokens: ["a", "b"] }),
      answer_json: JSON.stringify({ correct_order: [1, 0] }),
      difficulty: 1,
    });

    const res = await SELF.fetch("https://worker.test/v1/quiz/next?types=order", {
      headers: { Authorization: `Bearer ${token}` },
    });
    const body = await res.json<{ type: string }>();
    expect(body.type).toBe("order");
  });

  it("respects the user's level as a difficulty ceiling", async () => {
    const token = await registerAndAuth("quiz-dev-3", "beginner"); // ceiling = A2 = difficulty 2
    await insertQuiz({ difficulty: 5 }); // C1 — should never come back for a beginner

    const res = await SELF.fetch("https://worker.test/v1/quiz/next", { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status).toBe(404);
  });

  it("404s when nothing matches", async () => {
    const token = await registerAndAuth("quiz-dev-4");
    const res = await SELF.fetch("https://worker.test/v1/quiz/next", { headers: { Authorization: `Bearer ${token}` } });
    expect(res.status).toBe(404);
  });
});
