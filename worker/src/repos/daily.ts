import type { Env } from "../env";
import { cefrsUpTo, LEVEL_CEFR_CEILING } from "../cefr";
import type { ContentWordRow } from "./srs";

export interface DailySetRow {
  id: string;
  user_id: string;
  date: string; // YYYY-MM-DD in user tz
  word_ids_json: string;
  completed: number;
}

const DAILY_WORD_COUNT = 10;

export async function getDailySet(env: Env, userId: string, date: string): Promise<DailySetRow | null> {
  return env.DB.prepare("SELECT * FROM daily_sets WHERE user_id = ? AND date = ?").bind(userId, date).first<DailySetRow>();
}

/** Lazily creates today's 10-word set: not-yet-in-deck words, frequency-first, capped at the user's CEFR level. */
export async function createDailySet(
  env: Env,
  userId: string,
  date: string,
  targetLang: string,
  level: string,
): Promise<DailySetRow> {
  const cefrCeiling = LEVEL_CEFR_CEILING[level] ?? "A2";
  const allowedCefrs = cefrsUpTo(cefrCeiling);
  const placeholders = allowedCefrs.map(() => "?").join(",");

  const { results } = await env.DB.prepare(
    `SELECT w.id FROM content_words w
     WHERE w.lang = ? AND w.cefr IN (${placeholders})
       AND w.id NOT IN (SELECT word_id FROM user_cards WHERE user_id = ?)
     ORDER BY w.frequency_rank ASC
     LIMIT ?`,
  )
    .bind(targetLang, ...allowedCefrs, userId, DAILY_WORD_COUNT)
    .all<{ id: string }>();

  const wordIds = results.map((r) => r.id);
  const id = crypto.randomUUID();
  await env.DB.prepare(
    "INSERT INTO daily_sets (id, user_id, date, word_ids_json, completed) VALUES (?, ?, ?, ?, 0)",
  )
    .bind(id, userId, date, JSON.stringify(wordIds))
    .run();

  return { id, user_id: userId, date, word_ids_json: JSON.stringify(wordIds), completed: 0 };
}

export async function getWordsByIds(env: Env, wordIds: string[]): Promise<ContentWordRow[]> {
  if (wordIds.length === 0) return [];
  const placeholders = wordIds.map(() => "?").join(",");
  const { results } = await env.DB.prepare(`SELECT * FROM content_words WHERE id IN (${placeholders})`)
    .bind(...wordIds)
    .all<ContentWordRow>();
  // Preserve the daily set's original order (frequency-first) rather than whatever SQLite returns.
  const byId = new Map(results.map((w) => [w.id, w]));
  return wordIds.map((id) => byId.get(id)).filter((w): w is ContentWordRow => w !== undefined);
}

export async function markDailyCompleted(env: Env, userId: string, date: string): Promise<void> {
  await env.DB.prepare("UPDATE daily_sets SET completed = 1 WHERE user_id = ? AND date = ?").bind(userId, date).run();
}
