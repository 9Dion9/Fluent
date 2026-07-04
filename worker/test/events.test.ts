import { env, SELF } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";

async function registerDevice(pubid: string) {
  const res = await SELF.fetch("https://worker.test/v1/auth/device", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ device_pubid: pubid, device_secret: "s" }),
  });
  return res.json<{ user_id: string; token: string }>();
}

describe("POST /v1/events", () => {
  beforeEach(async () => {
    await env.DB.exec("DELETE FROM devices");
    await env.DB.exec("DELETE FROM users");
    await env.DB.exec("DELETE FROM events");
  });

  it("rejects an unauthenticated request", async () => {
    const res = await SELF.fetch("https://worker.test/v1/events", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify([{ name: "chat_turn", at: Date.now() }]),
    });
    expect(res.status).toBe(401);
  });

  it("rejects a malformed batch", async () => {
    const { token } = await registerDevice("events-dev-1");
    const res = await SELF.fetch("https://worker.test/v1/events", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify([{ props: {} }]), // missing required name/at
    });
    expect(res.status).toBe(400);
  });

  it("inserts a batch and returns 204", async () => {
    const { user_id, token } = await registerDevice("events-dev-2");
    const res = await SELF.fetch("https://worker.test/v1/events", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify([
        { name: "onboarding_step", props: { step: "welcome" }, at: 1000 },
        { name: "chat_turn", at: 1001 },
      ]),
    });
    expect(res.status).toBe(204);

    const { results } = await env.DB.prepare("SELECT name, props_json, created_at FROM events WHERE user_id = ? ORDER BY created_at")
      .bind(user_id)
      .all<{ name: string; props_json: string | null; created_at: number }>();
    expect(results).toHaveLength(2);
    expect(results[0]?.name).toBe("onboarding_step");
    expect(JSON.parse(results[0]?.props_json ?? "{}")).toEqual({ step: "welcome" });
    expect(results[1]?.name).toBe("chat_turn");
    expect(results[1]?.props_json).toBeNull();
  });

  it("degrades to 204 (never a hard error) once rate-limited", async () => {
    const { user_id, token } = await registerDevice("events-dev-3");
    await env.KV.put(`ratelimit:events:${user_id}:${Math.floor(Date.now() / 1000 / 86_400)}`, "5000");

    const res = await SELF.fetch("https://worker.test/v1/events", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify([{ name: "chat_turn", at: Date.now() }]),
    });
    expect(res.status).toBe(204); // fire-and-forget analytics never surface an error, per CLAUDE.md §14

    const { results } = await env.DB.prepare("SELECT id FROM events WHERE user_id = ?").bind(user_id).all();
    expect(results).toHaveLength(0); // and the dropped batch really wasn't written
  });
});
