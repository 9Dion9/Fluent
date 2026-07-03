import { Hono } from "hono";
import { z } from "zod";
import type { Env } from "../env";
import { AppError } from "../errors";
import { authenticate } from "../middleware/authenticate";
import { getUser, recordStreakActivity } from "../repos/users";
import { createDailySet, getDailySet, getWordsByIds, markDailyCompleted } from "../repos/daily";
import { addCardIfAbsent } from "../repos/srs";
import { toWordCard } from "../wordcard";
import { localDateString } from "../dateInTz";

export const dailyRoute = new Hono<{ Bindings: Env }>();
dailyRoute.use("*", authenticate);

const dailyCompleteSchema = z.object({ date: z.string() });

dailyRoute.get("/", async (c) => {
  const env = c.env;
  const userId = c.get("userId") as string;
  const user = await getUser(env, userId);
  if (!user) throw new AppError("unauthorized", "No such user.");

  const today = localDateString(user.tz);
  let set = await getDailySet(env, userId, today);
  if (!set) {
    set = await createDailySet(env, userId, today, user.target_lang, user.level);
    // Daily words auto-enter the deck immediately, same as camera words (CLAUDE.md §9).
    const now = Date.now();
    for (const wordId of JSON.parse(set.word_ids_json) as string[]) {
      await addCardIfAbsent(env, userId, wordId, "daily", now);
    }
  }

  const words = await getWordsByIds(env, JSON.parse(set.word_ids_json) as string[]);
  return c.json({ date: set.date, words: words.map(toWordCard), completed: set.completed === 1 });
});

dailyRoute.post("/complete", async (c) => {
  const env = c.env;
  const userId = c.get("userId") as string;
  const user = await getUser(env, userId);
  if (!user) throw new AppError("unauthorized", "No such user.");

  const parsed = dailyCompleteSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    throw new AppError("invalid_request", "Malformed daily-complete request.");
  }

  await markDailyCompleted(env, userId, parsed.data.date);
  const streak = await recordStreakActivity(env, userId, parsed.data.date);

  return c.json({ streak_current: streak.streak_current, streak_best: streak.streak_best });
});
