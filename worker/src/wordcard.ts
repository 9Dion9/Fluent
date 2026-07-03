import type { ContentWordRow } from "./repos/srs";

/** Maps a content_words D1 row to the shared/schemas/word-card.json shape. */
export function toWordCard(w: ContentWordRow) {
  return {
    id: w.id,
    lang: w.lang,
    word: w.word,
    translation: w.translation,
    pos: w.pos,
    gender: w.gender,
    ipa: w.ipa,
    cefr: w.cefr,
    topics: w.topics_json ? (JSON.parse(w.topics_json) as string[]) : [],
    example: w.example,
    example_translation: w.example_translation,
    audio_url: null, // pre-rendering to R2 isn't built yet (batch/README.md) — client falls back to /v1/tts + on-device
    source: w.source,
    verified: w.verified === 1,
  };
}
