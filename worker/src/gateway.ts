import type { Env } from "./env";

/** Worker->gateway /v1/chat: 25s timeout, no retries (avoid double generation), per CLAUDE.md §2. */
const CHAT_TIMEOUT_MS = 25_000;

export class GatewayCallError extends Error {}

/**
 * Calls the gateway's generic /v1/chat wrapper and returns the raw assistant
 * text (expected to be a JSON string matching ChatReply — validated by the
 * caller). Records the result against the circuit breaker either way.
 */
export async function callGatewayChat(
  env: Env,
  messages: { role: "system" | "user" | "assistant"; content: string }[],
): Promise<string> {
  try {
    const res = await fetch(`${env.GATEWAY_URL}/v1/chat`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Gateway-Secret": env.GATEWAY_SHARED_SECRET,
      },
      body: JSON.stringify({ messages }),
      signal: AbortSignal.timeout(CHAT_TIMEOUT_MS),
    });

    if (!res.ok) {
      await recordGatewayResult(env, false);
      throw new GatewayCallError(`gateway /v1/chat returned ${res.status}`);
    }

    const data = (await res.json()) as { text: string };
    await recordGatewayResult(env, true);
    return data.text;
  } catch (err) {
    if (err instanceof GatewayCallError) throw err;
    await recordGatewayResult(env, false);
    throw new GatewayCallError(String(err));
  }
}

const HEALTH_CACHE_KEY = "gw:health";
// KV enforces a 60s minimum TTL. CLAUDE.md §2 specs a 30s cache; 60s is the
// closest we can get without rolling a custom expiry check on read.
const HEALTH_CACHE_TTL_SECONDS = 60;
const CIRCUIT_BREAKER_KEY = "gw:circuit_open_until";
const CIRCUIT_BREAKER_FAILS_KEY = "gw:consecutive_fails";
const CIRCUIT_BREAKER_THRESHOLD = 3;
const CIRCUIT_BREAKER_COOLDOWN_SECONDS = 60;

export type GatewayHealth = "ok" | "down";

/**
 * Cached gateway health check (KV, 30s TTL) per CLAUDE.md §2 resilience rules.
 * A tripped circuit breaker (3 consecutive /chat or /tts failures) short-circuits
 * to "down" for 60s without hitting the network, so a napping gateway fails fast.
 */
export async function checkGatewayHealth(env: Env): Promise<GatewayHealth> {
  const circuitOpenUntil = await env.KV.get(CIRCUIT_BREAKER_KEY);
  if (circuitOpenUntil && Number(circuitOpenUntil) > Date.now()) {
    return "down";
  }

  const cached = await env.KV.get(HEALTH_CACHE_KEY);
  if (cached === "ok" || cached === "down") {
    return cached;
  }

  const health = await probeGateway(env);
  await env.KV.put(HEALTH_CACHE_KEY, health, { expirationTtl: HEALTH_CACHE_TTL_SECONDS });
  return health;
}

async function probeGateway(env: Env): Promise<GatewayHealth> {
  try {
    const res = await fetch(`${env.GATEWAY_URL}/healthz`, {
      method: "GET",
      signal: AbortSignal.timeout(5000),
    });
    return res.ok ? "ok" : "down";
  } catch {
    return "down";
  }
}

/** Call after every gateway request. Trips the breaker after 3 consecutive failures. */
export async function recordGatewayResult(env: Env, ok: boolean): Promise<void> {
  if (ok) {
    await env.KV.delete(CIRCUIT_BREAKER_FAILS_KEY);
    return;
  }
  const failsRaw = await env.KV.get(CIRCUIT_BREAKER_FAILS_KEY);
  const fails = (Number(failsRaw) || 0) + 1;
  if (fails >= CIRCUIT_BREAKER_THRESHOLD) {
    await env.KV.put(
      CIRCUIT_BREAKER_KEY,
      String(Date.now() + CIRCUIT_BREAKER_COOLDOWN_SECONDS * 1000),
      { expirationTtl: CIRCUIT_BREAKER_COOLDOWN_SECONDS },
    );
    await env.KV.delete(CIRCUIT_BREAKER_FAILS_KEY);
  } else {
    await env.KV.put(CIRCUIT_BREAKER_FAILS_KEY, String(fails), { expirationTtl: 300 });
  }
}
