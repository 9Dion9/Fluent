import { env, SELF } from "cloudflare:test";
import { describe, expect, it, beforeEach } from "vitest";

async function authedUser(pubid: string) {
  const res = await SELF.fetch("https://worker.test/v1/auth/device", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ device_pubid: pubid, device_secret: "secret" }),
  });
  return res.json<{ user_id: string; token: string }>();
}

describe("/v1/profile", () => {
  beforeEach(async () => {
    await env.DB.exec("DELETE FROM devices");
    await env.DB.exec("DELETE FROM users");
  });

  it("rejects requests with no bearer token", async () => {
    const res = await SELF.fetch("https://worker.test/v1/profile");
    expect(res.status).toBe(401);
  });

  it("returns onboarding-pending defaults right after device auth", async () => {
    const { token } = await authedUser("profile-dev-1");
    const res = await SELF.fetch("https://worker.test/v1/profile", {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(200);
    const body = await res.json<Record<string, unknown>>();
    expect(body.native_lang).toBe("en");
    expect(body.target_lang).toBe("de");
    expect(body.level).toBe("beginner");
    expect(body.interests).toEqual([]);
    expect(body.streak_current).toBe(0);
  });

  it("PUT updates the profile and GET reflects it (onboarding completion)", async () => {
    const { token } = await authedUser("profile-dev-2");
    const update = {
      native_lang: "en",
      target_lang: "de",
      level: "elementary",
      interests: ["travel", "food"],
      tutor_name: "Emma",
      tutor_persona: "sunny",
      tz: "Europe/Berlin",
      reminder_time: "19:00",
      daily_goal: 10,
    };

    const putRes = await SELF.fetch("https://worker.test/v1/profile", {
      method: "PUT",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify(update),
    });
    expect(putRes.status).toBe(200);
    const putBody = await putRes.json<Record<string, unknown>>();
    expect(putBody.tutor_name).toBe("Emma");
    expect(putBody.interests).toEqual(["travel", "food"]);

    const getRes = await SELF.fetch("https://worker.test/v1/profile", {
      headers: { Authorization: `Bearer ${token}` },
    });
    const getBody = await getRes.json<Record<string, unknown>>();
    expect(getBody).toEqual(putBody);
  });

  it("accepts a profile update with reminder_time omitted entirely", async () => {
    // Regression test: Swift's Encodable synthesis omits nil-optional fields
    // rather than sending an explicit `null` — this is exactly what the app
    // sends when the user skips the reminder step in onboarding.
    const { token } = await authedUser("profile-dev-5");
    const update = {
      native_lang: "en",
      target_lang: "de",
      level: "beginner",
      interests: ["travel", "food"],
      tutor_name: "Emma",
      tutor_persona: "sunny",
      tz: "Europe/Berlin",
      daily_goal: 10,
      // reminder_time deliberately omitted
    };

    const res = await SELF.fetch("https://worker.test/v1/profile", {
      method: "PUT",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify(update),
    });
    expect(res.status).toBe(200);
    const body = await res.json<Record<string, unknown>>();
    expect(body.reminder_time).toBeNull();
  });

  it("rejects an invalid profile update", async () => {
    const { token } = await authedUser("profile-dev-3");
    const res = await SELF.fetch("https://worker.test/v1/profile", {
      method: "PUT",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ level: "expert" /* not a valid enum value, and missing fields */ }),
    });
    expect(res.status).toBe(400);
  });

  it("rejects a tampered token", async () => {
    const { token } = await authedUser("profile-dev-4");
    const tampered = token.slice(0, -1) + (token.at(-1) === "a" ? "b" : "a");
    const res = await SELF.fetch("https://worker.test/v1/profile", {
      headers: { Authorization: `Bearer ${tampered}` },
    });
    expect(res.status).toBe(401);
  });
});
