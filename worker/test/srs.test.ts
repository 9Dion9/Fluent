import { env, SELF } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";

async function registerDevice(pubid: string) {
  const res = await SELF.fetch("https://worker.test/v1/auth/device", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ device_pubid: pubid, device_secret: "s" }),
  });
  return res.json<{ user_id: string; token: string }>();
}

async function seedWord(id: string, overrides: Partial<Record<string, unknown>> = {}) {
  const defaults = {
    id,
    lang: "de",
    word: id,
    translation: `translation-${id}`,
    pos: "noun",
    gender: "der",
    ipa: null,
    cefr: "A1",
    topics_json: "[]",
    frequency_rank: 1,
    example: null,
    example_translation: null,
    audio_key: null,
    source: "pipeline",
    verified: 1,
    ...overrides,
  };
  await env.DB.prepare(
    `INSERT INTO content_words (id, lang, word, translation, pos, gender, ipa, cefr, topics_json, frequency_rank, example, example_translation, audio_key, source, verified)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      defaults.id,
      defaults.lang,
      defaults.word,
      defaults.translation,
      defaults.pos,
      defaults.gender,
      defaults.ipa,
      defaults.cefr,
      defaults.topics_json,
      defaults.frequency_rank,
      defaults.example,
      defaults.example_translation,
      defaults.audio_key,
      defaults.source,
      defaults.verified,
    )
    .run();
}

describe("SRS + daily", () => {
  beforeEach(async () => {
    await env.DB.exec("DELETE FROM devices");
    await env.DB.exec("DELETE FROM users");
    await env.DB.exec("DELETE FROM content_words");
    await env.DB.exec("DELETE FROM user_cards");
    await env.DB.exec("DELETE FROM srs_state");
    await env.DB.exec("DELETE FROM reviews");
    await env.DB.exec("DELETE FROM daily_sets");
  });

  describe("GET /v1/daily", () => {
    it("lazily creates today's set from not-yet-in-deck words, frequency-first", async () => {
      const { token } = await registerDevice("srs-dev-1");
      for (let i = 1; i <= 15; i++) {
        await seedWord(`word-${i}`, { frequency_rank: i, cefr: "A1" });
      }

      const res = await SELF.fetch("https://worker.test/v1/daily", {
        headers: { Authorization: `Bearer ${token}` },
      });
      expect(res.status).toBe(200);
      const body = await res.json<{ date: string; words: { id: string }[]; completed: boolean }>();
      expect(body.words).toHaveLength(10);
      expect(body.words.map((w) => w.id)).toEqual(["word-1", "word-2", "word-3", "word-4", "word-5", "word-6", "word-7", "word-8", "word-9", "word-10"]);
      expect(body.completed).toBe(false);
    });

    it("is idempotent within the same day — repeat calls return the same set", async () => {
      const { token } = await registerDevice("srs-dev-2");
      for (let i = 1; i <= 12; i++) await seedWord(`w${i}`, { frequency_rank: i });

      const first = await SELF.fetch("https://worker.test/v1/daily", { headers: { Authorization: `Bearer ${token}` } });
      const firstBody = await first.json<{ words: { id: string }[] }>();

      const second = await SELF.fetch("https://worker.test/v1/daily", { headers: { Authorization: `Bearer ${token}` } });
      const secondBody = await second.json<{ words: { id: string }[] }>();

      expect(secondBody.words.map((w) => w.id)).toEqual(firstBody.words.map((w) => w.id));
    });

    it("auto-adds daily words to the deck (user_cards + srs_state)", async () => {
      const { token, user_id } = await registerDevice("srs-dev-3");
      await seedWord("solo-word", { frequency_rank: 1 });

      await SELF.fetch("https://worker.test/v1/daily", { headers: { Authorization: `Bearer ${token}` } });

      const card = await env.DB.prepare("SELECT * FROM user_cards WHERE user_id = ? AND word_id = ?")
        .bind(user_id, "solo-word")
        .first<{ id: string; source: string }>();
      expect(card?.source).toBe("daily");

      const srsState = await env.DB.prepare("SELECT * FROM srs_state WHERE card_id = ?").bind(card?.id).first<{ state: string }>();
      expect(srsState?.state).toBe("new");
    });

    it("excludes words already in the deck", async () => {
      const { token, user_id } = await registerDevice("srs-dev-4");
      await seedWord("already-known", { frequency_rank: 1 });
      await seedWord("new-word", { frequency_rank: 2 });
      await env.DB.prepare("INSERT INTO user_cards (id, user_id, word_id, source, added_at) VALUES (?, ?, ?, 'manual', ?)")
        .bind("card-1", user_id, "already-known", Date.now())
        .run();

      const res = await SELF.fetch("https://worker.test/v1/daily", { headers: { Authorization: `Bearer ${token}` } });
      const body = await res.json<{ words: { id: string }[] }>();
      expect(body.words.map((w) => w.id)).toEqual(["new-word"]);
    });
  });

  describe("POST /v1/daily/complete", () => {
    it("marks the set completed and updates the streak", async () => {
      const { token } = await registerDevice("srs-dev-5");
      const res = await SELF.fetch("https://worker.test/v1/daily/complete", {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify({ date: "2026-01-15" }),
      });
      expect(res.status).toBe(200);
      const body = await res.json<{ streak_current: number; streak_best: number }>();
      expect(body.streak_current).toBe(1);
      expect(body.streak_best).toBe(1);
    });
  });

  describe("GET /v1/srs/due + POST /v1/srs/review", () => {
    async function setUpOneCard(pubid: string) {
      const { token, user_id } = await registerDevice(pubid);
      await seedWord("due-word", { frequency_rank: 1 });
      await env.DB.prepare("INSERT INTO user_cards (id, user_id, word_id, source, added_at) VALUES (?, ?, ?, 'manual', ?)")
        .bind("card-due-1", user_id, "due-word", Date.now())
        .run();
      await env.DB.prepare(
        "INSERT INTO srs_state (card_id, user_id, due_at, stability, difficulty, reps, lapses, state, last_review_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
      )
        .bind("card-due-1", user_id, Date.now() - 1000, null, null, 0, 0, "new", null)
        .run();
      return { token, user_id };
    }

    it("returns due cards with the full word joined in", async () => {
      const { token } = await setUpOneCard("srs-dev-6");
      const res = await SELF.fetch("https://worker.test/v1/srs/due", { headers: { Authorization: `Bearer ${token}` } });
      expect(res.status).toBe(200);
      const body = await res.json<{ card_id: string; word: { word: string; gender: string } }[]>();
      expect(body).toHaveLength(1);
      expect(body[0]!.card_id).toBe("card-due-1");
      expect(body[0]!.word.word).toBe("due-word");
      expect(body[0]!.word.gender).toBe("der");
    });

    it("reschedules a card on review and updates the streak", async () => {
      const { token } = await setUpOneCard("srs-dev-7");
      const res = await SELF.fetch("https://worker.test/v1/srs/review", {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify([
          { id: "review-1", card_id: "card-due-1", rating: 3, elapsed_ms: 4000, reviewed_at: Date.now() },
        ]),
      });
      expect(res.status).toBe(200);
      const body = await res.json<{ card_id: string; next_due: number }[]>();
      expect(body).toHaveLength(1);
      expect(body[0]!.card_id).toBe("card-due-1");
      expect(body[0]!.next_due).toBeGreaterThan(Date.now());

      const state = await env.DB.prepare("SELECT * FROM srs_state WHERE card_id = ?").bind("card-due-1").first<{ reps: number; state: string }>();
      expect(state?.reps).toBe(1);
      expect(state?.state).not.toBe("new");
    });

    it("is idempotent — replaying the same review id doesn't reschedule twice", async () => {
      const { token } = await setUpOneCard("srs-dev-8");
      const review = { id: "review-dup", card_id: "card-due-1", rating: 3, elapsed_ms: 4000, reviewed_at: Date.now() };

      const first = await SELF.fetch("https://worker.test/v1/srs/review", {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify([review]),
      });
      const firstBody = await first.json<{ next_due: number }[]>();

      const second = await SELF.fetch("https://worker.test/v1/srs/review", {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify([review]),
      });
      const secondBody = await second.json<{ next_due: number }[]>();

      expect(secondBody[0]!.next_due).toBe(firstBody[0]!.next_due);
      const state = await env.DB.prepare("SELECT reps FROM srs_state WHERE card_id = ?").bind("card-due-1").first<{ reps: number }>();
      expect(state?.reps).toBe(1); // not 2 — the duplicate was a no-op
    });

    it("rejects a review for a card belonging to another user", async () => {
      await setUpOneCard("srs-dev-9");
      const { token: otherToken } = await registerDevice("srs-dev-9-other");

      const res = await SELF.fetch("https://worker.test/v1/srs/review", {
        method: "POST",
        headers: { Authorization: `Bearer ${otherToken}`, "Content-Type": "application/json" },
        body: JSON.stringify([
          { id: "review-hijack", card_id: "card-due-1", rating: 3, elapsed_ms: 1000, reviewed_at: Date.now() },
        ]),
      });
      expect(res.status).toBe(404);
    });
  });
});
