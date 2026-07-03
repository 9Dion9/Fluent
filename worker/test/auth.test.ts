import { env, SELF } from "cloudflare:test";
import { describe, expect, it, beforeEach } from "vitest";

async function registerDevice(pubid: string, secret: string) {
  return SELF.fetch("https://worker.test/v1/auth/device", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ device_pubid: pubid, device_secret: secret }),
  });
}

describe("POST /v1/auth/device", () => {
  beforeEach(async () => {
    await env.DB.exec("DELETE FROM devices");
    await env.DB.exec("DELETE FROM users");
  });

  it("creates a new user + device on first call", async () => {
    const res = await registerDevice("dev-1", "secret-1");
    expect(res.status).toBe(200);
    const body = await res.json<{ user_id: string; token: string }>();
    expect(body.user_id).toBeTruthy();
    expect(body.token.split(".")).toHaveLength(3);
  });

  it("returns the same user_id on a repeat call with the correct secret", async () => {
    const first = await registerDevice("dev-2", "secret-2");
    const firstBody = await first.json<{ user_id: string }>();

    const second = await registerDevice("dev-2", "secret-2");
    const secondBody = await second.json<{ user_id: string }>();

    expect(secondBody.user_id).toBe(firstBody.user_id);
  });

  it("rejects a repeat call with the wrong secret", async () => {
    await registerDevice("dev-3", "correct-secret");
    const res = await registerDevice("dev-3", "wrong-secret");
    expect(res.status).toBe(401);
    const body = await res.json<{ error: { code: string } }>();
    expect(body.error.code).toBe("unauthorized");
  });

  it("rejects a malformed request body", async () => {
    const res = await SELF.fetch("https://worker.test/v1/auth/device", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ device_pubid: "" }),
    });
    expect(res.status).toBe(400);
  });

  it("rate limits after 20 attempts from the same IP in an hour", async () => {
    const ip = "203.0.113.42";
    for (let i = 0; i < 20; i++) {
      const res = await SELF.fetch("https://worker.test/v1/auth/device", {
        method: "POST",
        headers: { "Content-Type": "application/json", "CF-Connecting-IP": ip },
        body: JSON.stringify({ device_pubid: `bulk-${i}`, device_secret: "s" }),
      });
      expect(res.status).toBe(200);
    }
    const res = await SELF.fetch("https://worker.test/v1/auth/device", {
      method: "POST",
      headers: { "Content-Type": "application/json", "CF-Connecting-IP": ip },
      body: JSON.stringify({ device_pubid: "bulk-20", device_secret: "s" }),
    });
    expect(res.status).toBe(429);
    const body = await res.json<{ error: { code: string } }>();
    expect(body.error.code).toBe("rate_limited");
  });
});
