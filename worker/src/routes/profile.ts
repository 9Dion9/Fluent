import { Hono } from "hono";
import type { Env } from "../env";
import { profileUpdateSchema } from "../schemas";
import { AppError, sendError } from "../errors";
import { authenticate } from "../middleware/authenticate";
import { getUser, updateProfile, type UserRow } from "../repos/users";

export const profileRoute = new Hono<{ Bindings: Env }>();
profileRoute.use("*", authenticate);

function toProfileResponse(user: UserRow) {
  return {
    id: user.id,
    native_lang: user.native_lang,
    target_lang: user.target_lang,
    level: user.level,
    interests: JSON.parse(user.interests_json) as string[],
    tutor_name: user.tutor_name,
    tutor_persona: user.tutor_persona,
    tz: user.tz,
    reminder_time: user.reminder_time,
    daily_goal: user.daily_goal,
    streak_current: user.streak_current,
    streak_best: user.streak_best,
    streak_freezes: user.streak_freezes,
  };
}

profileRoute.get("/", async (c) => {
  const user = await getUser(c.env, c.get("userId"));
  if (!user) {
    return sendError(c, new AppError("not_found", "No profile for this user."));
  }
  return c.json(toProfileResponse(user));
});

profileRoute.put("/", async (c) => {
  const parsed = profileUpdateSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    return sendError(c, new AppError("invalid_request", parsed.error.issues[0]?.message ?? "Invalid profile."));
  }

  const user = await updateProfile(c.env, c.get("userId"), parsed.data);
  return c.json(toProfileResponse(user));
});
