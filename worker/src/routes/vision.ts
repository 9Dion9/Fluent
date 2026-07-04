import { Hono } from "hono";
import type { Env } from "../env";
import { AppError } from "../errors";
import { authenticate } from "../middleware/authenticate";
import { visionIdentifyRequestSchema } from "../schemas";
import { getUser } from "../repos/users";
import { addCardIfAbsent } from "../repos/srs";
import { lookupVisionLabel, insertVlmContentWord, upsertVisionLabelMapping } from "../repos/vision";
import { toWordCard } from "../wordcard";
import { checkGatewayHealth, callGatewayVision, GatewayCallError } from "../gateway";
import { isRateLimited } from "../rateLimit";

export const visionRoute = new Hono<{ Bindings: Env }>();
visionRoute.use("*", authenticate);

const CAMERA_VLM_FALLBACK_PER_DAY = 20; // CLAUDE.md §13

visionRoute.post("/identify", async (c) => {
  const env = c.env;
  const userId = c.get("userId") as string;
  const now = Date.now();

  const parsed = visionIdentifyRequestSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    throw new AppError("invalid_request", "Provide an image and/or a detected_label.");
  }
  const { image_b64, detected_label } = parsed.data;

  const user = await getUser(env, userId);
  if (!user) throw new AppError("unauthorized", "No such user.");

  // Instant path: batch-built (or previously-learned) label -> word mapping. $0, no gateway call.
  const label = detected_label?.toLowerCase().trim();
  if (label) {
    const hit = await lookupVisionLabel(env, label, user.target_lang);
    if (hit) {
      await addCardIfAbsent(env, userId, hit.id, "camera", now);
      return c.json(toWordCard(hit));
    }
  }

  // Fallback needs an image (CLAUDE.md §6: "VLM fallback needs image").
  if (!image_b64) {
    throw new AppError("not_found", "No match for that object yet — try snapping a photo instead.");
  }

  if (await isRateLimited(env, `vision:${userId}`, CAMERA_VLM_FALLBACK_PER_DAY, 86_400)) {
    throw new AppError("rate_limited", "You've reached today's camera lookup limit — back tomorrow!", {
      retryable: false,
    });
  }

  const health = await checkGatewayHealth(env);
  if (health === "down") {
    throw new AppError("tutor_napping", "The camera lens is taking a quick nap — try again in a bit.", {
      retryable: true,
    });
  }

  let result;
  try {
    result = await callGatewayVision(env, image_b64, user.target_lang);
  } catch (err) {
    if (err instanceof GatewayCallError) {
      throw new AppError("tutor_napping", "Couldn't identify that — try again in a bit.", { retryable: true });
    }
    throw err;
  }

  const word = await insertVlmContentWord(env, {
    lang: user.target_lang,
    word: result.word,
    translation: result.translation,
    pos: result.pos,
    gender: result.gender,
    example: result.example,
  });

  if (label) {
    await upsertVisionLabelMapping(env, label, user.target_lang, word.id);
  }

  await addCardIfAbsent(env, userId, word.id, "camera", now);
  return c.json(toWordCard(word));
});
