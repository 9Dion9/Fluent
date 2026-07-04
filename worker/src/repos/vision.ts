import type { Env } from "../env";
import type { ContentWordRow } from "./srs";

/** Instant path (CLAUDE.md §9): batch-built label -> content_words mapping. */
export async function lookupVisionLabel(env: Env, label: string, lang: string): Promise<ContentWordRow | null> {
  return env.DB.prepare(
    `SELECT w.* FROM vision_labels v
     JOIN content_words w ON w.id = v.word_id
     WHERE v.label = ? AND v.lang = ?`,
  )
    .bind(label, lang)
    .first<ContentWordRow>();
}

/** Inserts a VLM-identified word. Not Wiktionary-verified — flagged accordingly (CLAUDE.md §3, §9). */
export async function insertVlmContentWord(
  env: Env,
  params: { lang: string; word: string; translation: string; pos: string | null; gender: string | null; example: string | null },
): Promise<ContentWordRow> {
  const existing = await env.DB.prepare("SELECT * FROM content_words WHERE lang = ? AND word = ?")
    .bind(params.lang, params.word)
    .first<ContentWordRow>();
  if (existing) return existing;

  const id = crypto.randomUUID();
  await env.DB.prepare(
    `INSERT INTO content_words
       (id, lang, word, translation, pos, gender, ipa, cefr, topics_json, frequency_rank, example, example_translation, audio_key, source, verified)
     VALUES (?, ?, ?, ?, ?, ?, NULL, 'A1', '[]', NULL, ?, NULL, NULL, 'camera_vlm', 0)`,
  )
    .bind(id, params.lang, params.word, params.translation, params.pos, params.gender, params.example)
    .run();

  const row = await env.DB.prepare("SELECT * FROM content_words WHERE id = ?").bind(id).first<ContentWordRow>();
  if (!row) throw new Error("failed to read back inserted content_word");
  return row;
}

/** Caches the label -> word mapping so the next identical sighting hits the instant path. */
export async function upsertVisionLabelMapping(env: Env, label: string, lang: string, wordId: string): Promise<void> {
  await env.DB.prepare("INSERT OR IGNORE INTO vision_labels (label, lang, word_id) VALUES (?, ?, ?)")
    .bind(label, lang, wordId)
    .run();
}
