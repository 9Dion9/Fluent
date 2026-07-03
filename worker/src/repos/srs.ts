import type { Env } from "../env";
import { newCardRow, type ScheduleResult } from "../srs";

export interface SrsStateRow {
  card_id: string;
  user_id: string;
  due_at: number;
  stability: number | null;
  difficulty: number | null;
  reps: number;
  lapses: number;
  state: "new" | "learning" | "review" | "relearning";
  last_review_at: number | null;
}

export interface ContentWordRow {
  id: string;
  lang: string;
  word: string;
  translation: string;
  pos: string | null;
  gender: string | null;
  ipa: string | null;
  cefr: string;
  topics_json: string | null;
  frequency_rank: number | null;
  example: string | null;
  example_translation: string | null;
  audio_key: string | null;
  source: string;
  verified: number;
}

/** Adds a word to the user's deck (user_cards) with a fresh srs_state row, if not already present. Idempotent. */
export async function addCardIfAbsent(
  env: Env,
  userId: string,
  wordId: string,
  source: "daily" | "camera" | "chat" | "manual",
  now: number,
): Promise<string> {
  const existing = await env.DB.prepare("SELECT id FROM user_cards WHERE user_id = ? AND word_id = ?")
    .bind(userId, wordId)
    .first<{ id: string }>();
  if (existing) return existing.id;

  const cardId = crypto.randomUUID();
  const fresh: ScheduleResult = newCardRow(new Date(now));
  await env.DB.batch([
    env.DB.prepare("INSERT INTO user_cards (id, user_id, word_id, source, added_at) VALUES (?, ?, ?, ?, ?)").bind(
      cardId,
      userId,
      wordId,
      source,
      now,
    ),
    env.DB.prepare(
      "INSERT INTO srs_state (card_id, user_id, due_at, stability, difficulty, reps, lapses, state, last_review_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
    ).bind(cardId, userId, fresh.due_at, fresh.stability, fresh.difficulty, fresh.reps, fresh.lapses, fresh.state, fresh.last_review_at),
  ]);
  return cardId;
}

export async function getSrsState(env: Env, cardId: string): Promise<SrsStateRow | null> {
  return env.DB.prepare("SELECT * FROM srs_state WHERE card_id = ?").bind(cardId).first<SrsStateRow>();
}

export async function updateSrsState(env: Env, cardId: string, result: ScheduleResult): Promise<void> {
  await env.DB.prepare(
    "UPDATE srs_state SET due_at = ?, stability = ?, difficulty = ?, reps = ?, lapses = ?, state = ?, last_review_at = ? WHERE card_id = ?",
  )
    .bind(result.due_at, result.stability, result.difficulty, result.reps, result.lapses, result.state, result.last_review_at, cardId)
    .run();
}

export async function reviewExists(env: Env, reviewId: string): Promise<boolean> {
  const row = await env.DB.prepare("SELECT id FROM reviews WHERE id = ?").bind(reviewId).first<{ id: string }>();
  return row !== null;
}

export async function insertReview(
  env: Env,
  params: { id: string; cardId: string; userId: string; rating: number; reviewedAt: number; elapsedMs: number },
): Promise<void> {
  await env.DB.prepare(
    "INSERT INTO reviews (id, card_id, user_id, rating, reviewed_at, elapsed_ms) VALUES (?, ?, ?, ?, ?, ?)",
  )
    .bind(params.id, params.cardId, params.userId, params.rating, params.reviewedAt, params.elapsedMs)
    .run();
}

const DUE_QUEUE_CAP = 100; // CLAUDE.md §6

export async function getDueCards(env: Env, userId: string, now: number): Promise<(SrsStateRow & { word: ContentWordRow })[]> {
  const { results } = await env.DB.prepare(
    `SELECT s.*, w.id as w_id, w.lang as w_lang, w.word as w_word, w.translation as w_translation,
            w.pos as w_pos, w.gender as w_gender, w.ipa as w_ipa, w.cefr as w_cefr,
            w.topics_json as w_topics_json, w.frequency_rank as w_frequency_rank,
            w.example as w_example, w.example_translation as w_example_translation,
            w.audio_key as w_audio_key, w.source as w_source, w.verified as w_verified
     FROM srs_state s
     JOIN user_cards c ON c.id = s.card_id
     JOIN content_words w ON w.id = c.word_id
     WHERE s.user_id = ? AND s.due_at <= ?
     ORDER BY s.due_at ASC
     LIMIT ?`,
  )
    .bind(userId, now, DUE_QUEUE_CAP)
    .all<Record<string, unknown>>();

  return results.map((r) => ({
    card_id: r.card_id as string,
    user_id: r.user_id as string,
    due_at: r.due_at as number,
    stability: r.stability as number | null,
    difficulty: r.difficulty as number | null,
    reps: r.reps as number,
    lapses: r.lapses as number,
    state: r.state as SrsStateRow["state"],
    last_review_at: r.last_review_at as number | null,
    word: {
      id: r.w_id as string,
      lang: r.w_lang as string,
      word: r.w_word as string,
      translation: r.w_translation as string,
      pos: r.w_pos as string | null,
      gender: r.w_gender as string | null,
      ipa: r.w_ipa as string | null,
      cefr: r.w_cefr as string,
      topics_json: r.w_topics_json as string | null,
      frequency_rank: r.w_frequency_rank as number | null,
      example: r.w_example as string | null,
      example_translation: r.w_example_translation as string | null,
      audio_key: r.w_audio_key as string | null,
      source: r.w_source as string,
      verified: r.w_verified as number,
    },
  }));
}
