import { env, fetchMock, SELF } from "cloudflare:test";
import { afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { stripForSpeech } from "../src/tts";

const GATEWAY_ORIGIN = "https://gateway.fluent.example.com";
const FAKE_AUDIO = new Uint8Array([1, 2, 3, 4]);

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

async function registerDevice(pubid: string) {
  const res = await SELF.fetch("https://worker.test/v1/auth/device", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ device_pubid: pubid, device_secret: "s" }),
  });
  return res.json<{ user_id: string; token: string }>();
}

async function requestTTS(token: string, body: Record<string, unknown>) {
  return SELF.fetch("https://worker.test/v1/tts", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  });
}

function mockHealthy() {
  fetchMock.get(GATEWAY_ORIGIN).intercept({ path: "/healthz", method: "GET" }).reply(200, "ok");
}

function mockTTSRender() {
  fetchMock
    .get(GATEWAY_ORIGIN)
    .intercept({ path: "/v1/tts", method: "POST" })
    .reply(200, Buffer.from(FAKE_AUDIO), { headers: { "content-type": "audio/mp4" } });
}

describe("stripForSpeech", () => {
  it("removes emoji so Piper doesn't read out their Unicode name", () => {
    expect(stripForSpeech("Hallo! 😊 Wie geht's?")).toBe("Hallo! Wie geht's?");
  });

  it("removes variation selectors and zero-width joiners riding along with emoji", () => {
    expect(stripForSpeech("Toll gemacht! 🎉👍🏻")).toBe("Toll gemacht!");
  });

  it("leaves plain text untouched", () => {
    expect(stripForSpeech("Ich bin ein Student.")).toBe("Ich bin ein Student.");
  });
});

describe("POST /v1/tts", () => {
  beforeEach(async () => {
    await env.DB.exec("DELETE FROM devices");
    await env.DB.exec("DELETE FROM users");
    await env.KV.delete("gw:health");
    await env.KV.delete("gw:circuit_open_until");
    await env.KV.delete("gw:consecutive_fails");
  });

  it("rejects an unauthenticated request", async () => {
    const res = await requestTTS("bogus", { text: "Hallo", lang: "de" });
    expect(res.status).toBe(401);
  });

  it("rejects text over 400 characters", async () => {
    const { token } = await registerDevice("tts-dev-1");
    const res = await requestTTS(token, { text: "a".repeat(401), lang: "de" });
    expect(res.status).toBe(400);
  });

  it("rejects a language with no configured voice", async () => {
    const { token } = await registerDevice("tts-dev-2");
    const res = await requestTTS(token, { text: "Bonjour", lang: "fr" });
    expect(res.status).toBe(400);
  });

  it("renders on a cache miss and returns a fetchable audio_url", async () => {
    const { token } = await registerDevice("tts-dev-3");
    mockHealthy();
    mockTTSRender();

    const res = await requestTTS(token, { text: "Hallo!", lang: "de" });
    expect(res.status).toBe(200);
    const body = await res.json<{ audio_url: string }>();
    expect(body.audio_url).toMatch(/^https:\/\/worker\.test\/v1\/audio\/de\/[a-f0-9]{64}\.m4a$/);

    const audioRes = await SELF.fetch(body.audio_url);
    expect(audioRes.status).toBe(200);
    expect(audioRes.headers.get("Content-Type")).toBe("audio/mp4");
    expect(new Uint8Array(await audioRes.arrayBuffer())).toEqual(FAKE_AUDIO);
  });

  it("serves a cache hit without touching the gateway or the rate limit", async () => {
    const { token, user_id } = await registerDevice("tts-dev-4");
    mockHealthy();
    mockTTSRender();
    const first = await requestTTS(token, { text: "Danke!", lang: "de" });
    const { audio_url } = await first.json<{ audio_url: string }>();

    // Exhaust the rate limit, then confirm the identical text still succeeds from cache.
    await env.KV.put(`ratelimit:tts:${user_id}:${Math.floor(Date.now() / 1000 / 86_400)}`, "200");
    const second = await requestTTS(token, { text: "Danke!", lang: "de" });
    expect(second.status).toBe(200);
    const secondBody = await second.json<{ audio_url: string }>();
    expect(secondBody.audio_url).toBe(audio_url);
  });

  it("fails fast with tutor_napping when the gateway is unreachable", async () => {
    const { token } = await registerDevice("tts-dev-5");
    const res = await requestTTS(token, { text: "Unique uncached text", lang: "de" });
    expect(res.status).toBe(503);
    const body = await res.json<{ error: { code: string } }>();
    expect(body.error.code).toBe("tutor_napping");
  });

  it("rate limits live renders after the daily cap", async () => {
    const { token, user_id } = await registerDevice("tts-dev-6");
    await env.KV.put(`ratelimit:tts:${user_id}:${Math.floor(Date.now() / 1000 / 86_400)}`, "200");

    const res = await requestTTS(token, { text: "Never rendered before", lang: "de" });
    expect(res.status).toBe(429);
  });
});

describe("GET /v1/audio/:lang/:filename", () => {
  it("404s on a malformed key instead of touching R2 with a raw path", async () => {
    const res = await SELF.fetch("https://worker.test/v1/audio/de/../../secrets.txt");
    expect(res.status).toBe(404);
  });

  it("404s on a well-formed but nonexistent key", async () => {
    const res = await SELF.fetch(`https://worker.test/v1/audio/de/${"0".repeat(64)}.m4a`);
    expect(res.status).toBe(404);
  });
});
