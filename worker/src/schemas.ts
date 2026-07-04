// zod mirrors of /shared/schemas/*.json — the JSON Schema is canonical.
// If you change a contract, edit /shared first, then this file, in the same commit.
import { z } from "zod";

const cefrSchema = z.enum(["A1", "A2", "B1", "B2", "C1"]);

export const wordCardSchema = z.object({
  id: z.string(),
  lang: z.string().min(2).max(5),
  word: z.string(),
  translation: z.string(),
  pos: z.string().nullable().optional(),
  gender: z.string().nullable().optional(),
  ipa: z.string().nullable().optional(),
  cefr: cefrSchema,
  topics: z.array(z.string()).optional(),
  example: z.string().nullable().optional(),
  example_translation: z.string().nullable().optional(),
  audio_url: z.string().url().nullable().optional(),
  source: z.enum(["pipeline", "camera_vlm"]).optional(),
  verified: z.boolean().optional(),
});

export type WordCard = z.infer<typeof wordCardSchema>;

export const cardSchema = z.object({
  card_id: z.string(),
  word: wordCardSchema,
  due_at: z.number().int(),
  stability: z.number().nullable().optional(),
  difficulty: z.number().nullable().optional(),
  reps: z.number().int().min(0),
  lapses: z.number().int().min(0),
  state: z.enum(["new", "learning", "review", "relearning"]),
  last_review_at: z.number().int().nullable().optional(),
});

export type Card = z.infer<typeof cardSchema>;

export const chatReplySchema = z.object({
  reply: z.string(),
  reply_target_text: z.string(),
  corrections: z.array(
    z.object({
      original: z.string(),
      corrected: z.string(),
      explanation: z.string(),
    }),
  ),
  suggested_replies: z.array(z.string()).max(4),
  new_vocab: z.array(
    z.object({
      word: z.string(),
      translation: z.string(),
      example: z.string(),
    }),
  ),
});

export type ChatReply = z.infer<typeof chatReplySchema>;

export const chatRequestSchema = z.object({
  conversation_id: z.string().optional(),
  scenario_id: z.string().optional(),
  text: z.string().min(1),
});

export const ttsRequestSchema = z.object({
  text: z.string().min(1).max(400), // CLAUDE.md §6: "text <= 400 chars"
  lang: z.string().min(2).max(5),
});

export const quizSchema = z.object({
  id: z.string(),
  lang: z.string().min(2).max(5),
  type: z.enum(["mcq", "match", "fillblank", "order"]),
  prompt: z.record(z.unknown()),
  answer: z.record(z.unknown()),
  difficulty: z.number().int().min(1).max(5),
  word_ids: z.array(z.string()).optional(),
});

export type Quiz = z.infer<typeof quizSchema>;

export const scenarioSchema = z.object({
  id: z.string(),
  lang: z.string().min(2).max(5),
  title: z.string(),
  emoji: z.string().nullable().optional(),
  min_level: cefrSchema,
  seed_prompt: z.string(),
  focus_word_ids: z.array(z.string()).optional(),
});

export type Scenario = z.infer<typeof scenarioSchema>;

export const profileUpdateSchema = z.object({
  native_lang: z.string().min(2).max(5),
  target_lang: z.string().min(2).max(5),
  level: z.enum(["beginner", "elementary", "intermediate", "advanced"]),
  interests: z.array(z.string()),
  tutor_name: z.string().min(1),
  tutor_persona: z.enum(["sunny", "dry", "professor"]),
  tz: z.string(),
  // `.optional()` because Swift's Encodable synthesis omits nil-optional
  // fields entirely rather than sending an explicit `null` — the client
  // never sends this key at all when there's no reminder set.
  reminder_time: z
    .string()
    .regex(/^([01]\d|2[0-3]):[0-5]\d$/)
    .nullable()
    .optional(),
  daily_goal: z.number().int().positive(),
});

export const deviceAuthRequestSchema = z.object({
  device_pubid: z.string().min(1),
  device_secret: z.string().min(1),
});

export const srsReviewSchema = z.array(
  z.object({
    id: z.string(),
    card_id: z.string(),
    rating: z.number().int().min(1).max(4),
    elapsed_ms: z.number().int().nonnegative(),
    reviewed_at: z.number().int(),
  }),
);

export const eventsSchema = z.array(
  z.object({
    name: z.string(),
    props: z.record(z.unknown()).optional(),
    at: z.number().int(),
  }),
);

export const visionIdentifyRequestSchema = z
  .object({
    image_b64: z.string().min(1).optional(),
    detected_label: z.string().min(1).optional(),
  })
  .refine((v) => v.image_b64 || v.detected_label, {
    message: "at least one of image_b64 or detected_label is required",
  });
