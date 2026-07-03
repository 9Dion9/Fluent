import { Hono } from "hono";
import type { Env } from "../env";
import { AppError, sendError } from "../errors";

export const audioRoute = new Hono<{ Bindings: Env }>();

// Deliberately unauthenticated — TTS audio is meant to be a cacheable public
// URL an <audio>/AVPlayer can fetch directly (CLAUDE.md §8), gated only by
// the unguessable sha256 key. Path is validated to prevent R2 key traversal.
const FILENAME_PATTERN = /^[a-f0-9]{64}\.m4a$/;
const LANG_PATTERN = /^[a-z]{2,5}$/;

audioRoute.get("/:lang/:filename", async (c) => {
  const lang = c.req.param("lang");
  const filename = c.req.param("filename");

  if (!LANG_PATTERN.test(lang) || !FILENAME_PATTERN.test(filename)) {
    return sendError(c, new AppError("not_found", "No such audio."));
  }

  const object = await c.env.AUDIO.get(`tts/${lang}/${filename}`);
  if (!object) {
    return sendError(c, new AppError("not_found", "No such audio."));
  }

  return new Response(object.body, {
    headers: {
      "Content-Type": object.httpMetadata?.contentType ?? "audio/mp4",
      "Cache-Control": object.httpMetadata?.cacheControl ?? "public, max-age=31536000, immutable",
    },
  });
});
