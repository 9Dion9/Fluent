import { Hono } from "hono";
import type { Env } from "../env";
import { AppError } from "../errors";
import { authenticate } from "../middleware/authenticate";
import { ttsRequestSchema } from "../schemas";
import { isRateLimited } from "../rateLimit";
import { checkGatewayHealth, callGatewayTTS, GatewayCallError } from "../gateway";
import { audioKey, stripForSpeech, voiceForLang } from "../tts";

export const ttsRoute = new Hono<{ Bindings: Env }>();
ttsRoute.use("*", authenticate);

const LIVE_RENDERS_PER_DAY = 200; // CLAUDE.md §13 — R2 cache hits don't count against this

ttsRoute.post("/", async (c) => {
  const env = c.env;
  const userId = c.get("userId") as string;

  const parsed = ttsRequestSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    throw new AppError("invalid_request", "Malformed TTS request.");
  }
  const { lang } = parsed.data;
  const text = stripForSpeech(parsed.data.text);
  if (!text) {
    throw new AppError("invalid_request", "Nothing to speak after removing emoji/symbols.");
  }

  const voice = voiceForLang(lang);
  if (!voice) {
    throw new AppError("invalid_request", `No voice configured for lang=${lang}.`);
  }

  const key = await audioKey(text, lang, voice);

  // Cache hit — free, doesn't touch the rate limit or the gateway at all.
  const existing = await env.AUDIO.head(key);
  if (existing) {
    return c.json({ audio_url: publicAudioUrl(c.req.url, key) });
  }

  if (await isRateLimited(env, `tts:${userId}`, LIVE_RENDERS_PER_DAY, 86_400)) {
    throw new AppError("rate_limited", "You've reached today's voice limit — back tomorrow!", {
      retryable: false,
    });
  }

  const health = await checkGatewayHealth(env);
  if (health === "down") {
    throw new AppError("tutor_napping", "Voice is napping — text still works.", { retryable: true });
  }

  let audio: ArrayBuffer;
  try {
    audio = await callGatewayTTS(env, text, lang);
  } catch (err) {
    if (err instanceof GatewayCallError) {
      throw new AppError("tutor_napping", "Couldn't render audio — try again in a bit.", { retryable: true });
    }
    throw err;
  }

  await env.AUDIO.put(key, audio, {
    httpMetadata: { contentType: "audio/mp4", cacheControl: "public, max-age=31536000, immutable" },
  });

  return c.json({ audio_url: publicAudioUrl(c.req.url, key) });
});

function publicAudioUrl(requestUrl: string, key: string): string {
  return `${new URL(requestUrl).origin}/v1/audio/${key.slice("tts/".length)}`;
}
