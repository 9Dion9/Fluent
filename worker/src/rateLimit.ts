import type { Env } from "./env";

/**
 * Fixed-window counter in KV. Returns true if the caller is currently over limit.
 * windowSeconds also becomes the KV entry's TTL, so old windows self-expire.
 */
export async function isRateLimited(
  env: Env,
  key: string,
  limit: number,
  windowSeconds: number,
): Promise<boolean> {
  const bucket = Math.floor(Date.now() / 1000 / windowSeconds);
  const kvKey = `ratelimit:${key}:${bucket}`;
  const current = Number((await env.KV.get(kvKey)) ?? "0");

  if (current >= limit) return true;

  await env.KV.put(kvKey, String(current + 1), { expirationTtl: windowSeconds });
  return false;
}
