import type { Env } from "../env";

export interface QuizRow {
  id: string;
  lang: string;
  type: string;
  prompt_json: string;
  answer_json: string;
  difficulty: number;
  word_ids_json: string | null;
}

const ALL_TYPES = ["mcq", "match", "fillblank", "order"];

export async function getRandomQuiz(
  env: Env,
  lang: string,
  types: string[],
  maxDifficulty: number,
): Promise<QuizRow | null> {
  const wantedTypes = types.length > 0 ? types.filter((t) => ALL_TYPES.includes(t)) : ALL_TYPES;
  if (wantedTypes.length === 0) return null;
  const placeholders = wantedTypes.map(() => "?").join(",");

  return env.DB.prepare(
    `SELECT * FROM quizzes WHERE lang = ? AND type IN (${placeholders}) AND difficulty <= ?
     ORDER BY RANDOM() LIMIT 1`,
  )
    .bind(lang, ...wantedTypes, maxDifficulty)
    .first<QuizRow>();
}
