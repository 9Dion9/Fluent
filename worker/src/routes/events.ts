import { Hono } from "hono";
import type { Env } from "../env";
import { AppError } from "../errors";
import { authenticate } from "../middleware/authenticate";
import { eventsSchema } from "../schemas";
import { insertEvents } from "../repos/events";
import { isRateLimited } from "../rateLimit";

export const eventsRoute = new Hono<{ Bindings: Env }>();
eventsRoute.use("*", authenticate);

// Generous, not a real abuse surface (fire-and-forget analytics batches) —
// exists so a runaway client can't wedge D1, per CLAUDE.md §13's "rate
// limits everywhere" posture.
const EVENTS_PER_DAY = 5000;

eventsRoute.post("/", async (c) => {
  const env = c.env;
  const userId = c.get("userId") as string;

  const parsed = eventsSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    throw new AppError("invalid_request", "Malformed events batch.");
  }

  if (await isRateLimited(env, `events:${userId}`, EVENTS_PER_DAY, 86_400)) {
    // Analytics dropping silently is the correct degradation here — never
    // surface a hard error for a fire-and-forget background batch.
    return c.body(null, 204);
  }

  await insertEvents(env, userId, parsed.data);
  return c.body(null, 204);
});
