import { Hono } from "hono";
import type { Env } from "../env";
import { AppError } from "../errors";
import { authenticate } from "../middleware/authenticate";
import { srsReviewSchema } from "../schemas";
import { getUser, recordStreakActivity } from "../repos/users";
import { getDueCards, getSrsState, insertReview, reviewExists, updateSrsState } from "../repos/srs";
import { rowToFSRSCard, scheduleReview } from "../srs";
import { toWordCard } from "../wordcard";
import { localDateString } from "../dateInTz";

export const srsRoute = new Hono<{ Bindings: Env }>();
srsRoute.use("*", authenticate);

srsRoute.get("/due", async (c) => {
  const userId = c.get("userId") as string;
  const cards = await getDueCards(c.env, userId, Date.now());
  return c.json(
    cards.map((card) => ({
      card_id: card.card_id,
      word: toWordCard(card.word),
      due_at: card.due_at,
      stability: card.stability,
      difficulty: card.difficulty,
      reps: card.reps,
      lapses: card.lapses,
      state: card.state,
      last_review_at: card.last_review_at,
    })),
  );
});

/**
 * Batch, idempotent upsert by client id — this is the offline sync path
 * (CLAUDE.md §6). Reviews already applied (same client-generated id) are
 * skipped rather than re-scheduling the card a second time.
 */
srsRoute.post("/review", async (c) => {
  const env = c.env;
  const userId = c.get("userId") as string;

  const parsed = srsReviewSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    throw new AppError("invalid_request", "Malformed review batch.");
  }

  const results: { card_id: string; next_due: number }[] = [];
  let anyApplied = false;

  for (const review of parsed.data) {
    if (await reviewExists(env, review.id)) {
      const current = await getSrsState(env, review.card_id);
      if (current) results.push({ card_id: review.card_id, next_due: current.due_at });
      continue;
    }

    const current = await getSrsState(env, review.card_id);
    if (!current || current.user_id !== userId) {
      throw new AppError("not_found", `No such card: ${review.card_id}`);
    }

    const scheduled = scheduleReview(rowToFSRSCard(current), review.rating as 1 | 2 | 3 | 4, new Date(review.reviewed_at));
    await updateSrsState(env, review.card_id, scheduled);
    await insertReview(env, {
      id: review.id,
      cardId: review.card_id,
      userId,
      rating: review.rating,
      reviewedAt: review.reviewed_at,
      elapsedMs: review.elapsed_ms,
    });

    results.push({ card_id: review.card_id, next_due: scheduled.due_at });
    anyApplied = true;
  }

  if (anyApplied) {
    const user = await getUser(env, userId);
    if (user) await recordStreakActivity(env, userId, localDateString(user.tz));
  }

  return c.json(results);
});
