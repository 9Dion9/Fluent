import type { Env } from "../env";

export interface UserRow {
  id: string;
  created_at: number;
  native_lang: string;
  target_lang: string;
  level: string;
  interests_json: string;
  tutor_name: string;
  tutor_persona: string;
  tz: string;
  reminder_time: string | null;
  daily_goal: number;
  streak_current: number;
  streak_best: number;
  streak_freezes: number;
  last_active_date: string | null;
  auth_kind: string;
  apple_sub: string | null;
}

export interface DeviceRow {
  id: string;
  user_id: string;
  secret_hash: string;
  created_at: number;
  last_seen_at: number | null;
}

const NEW_USER_DEFAULTS = {
  native_lang: "en",
  target_lang: "de",
  level: "beginner",
  interests_json: "[]",
  tutor_name: "Tutor",
} as const;

export async function findDevice(env: Env, devicePubid: string): Promise<DeviceRow | null> {
  return env.DB.prepare("SELECT * FROM devices WHERE id = ?").bind(devicePubid).first<DeviceRow>();
}

export async function touchDeviceLastSeen(env: Env, devicePubid: string, now: number): Promise<void> {
  await env.DB.prepare("UPDATE devices SET last_seen_at = ? WHERE id = ?").bind(now, devicePubid).run();
}

/** Creates a new user (with onboarding-pending defaults) and its device record. */
export async function createUserWithDevice(
  env: Env,
  devicePubid: string,
  secretHash: string,
  now: number,
): Promise<UserRow> {
  const userId = crypto.randomUUID();
  await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO users (id, created_at, native_lang, target_lang, level, interests_json, tutor_name, auth_kind)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'device')`,
    ).bind(
      userId,
      now,
      NEW_USER_DEFAULTS.native_lang,
      NEW_USER_DEFAULTS.target_lang,
      NEW_USER_DEFAULTS.level,
      NEW_USER_DEFAULTS.interests_json,
      NEW_USER_DEFAULTS.tutor_name,
    ),
    env.DB.prepare(
      "INSERT INTO devices (id, user_id, secret_hash, created_at, last_seen_at) VALUES (?, ?, ?, ?, ?)",
    ).bind(devicePubid, userId, secretHash, now, now),
  ]);

  const user = await getUser(env, userId);
  if (!user) throw new Error("failed to read back just-created user");
  return user;
}

export async function getUser(env: Env, userId: string): Promise<UserRow | null> {
  return env.DB.prepare("SELECT * FROM users WHERE id = ?").bind(userId).first<UserRow>();
}

export interface StreakResult {
  streak_current: number;
  streak_best: number;
  streak_freezes: number;
  freeze_consumed: boolean;
}

/**
 * Qualifying activity (>=1 review, daily set completed — CLAUDE.md §0.6) on
 * `today` (YYYY-MM-DD, user's local date). Idempotent per day: calling this
 * twice on the same date is a no-op the second time. One freeze is earned
 * per 7-day streak (max 2 banked) and silently consumed on a missed day if
 * one's available, per CLAUDE.md §10.
 */
export async function recordStreakActivity(env: Env, userId: string, today: string): Promise<StreakResult> {
  const user = await getUser(env, userId);
  if (!user) throw new Error("recordStreakActivity: user not found");

  if (user.last_active_date === today) {
    return {
      streak_current: user.streak_current,
      streak_best: user.streak_best,
      streak_freezes: user.streak_freezes,
      freeze_consumed: false,
    };
  }

  const daysSinceLastActive = user.last_active_date
    ? Math.round((Date.parse(today) - Date.parse(user.last_active_date)) / 86_400_000)
    : null;

  let streakCurrent: number;
  let freezes = user.streak_freezes;
  let freezeConsumed = false;

  if (daysSinceLastActive === 1) {
    streakCurrent = user.streak_current + 1;
  } else if (daysSinceLastActive === 2 && freezes > 0) {
    // Exactly one day was missed and a freeze is banked — consume it silently.
    streakCurrent = user.streak_current + 1;
    freezes -= 1;
    freezeConsumed = true;
  } else {
    streakCurrent = 1; // first-ever activity, or the gap was too large to save
  }

  if (streakCurrent > 0 && streakCurrent % 7 === 0 && freezes < 2) {
    freezes += 1;
  }

  const streakBest = Math.max(user.streak_best, streakCurrent);

  await env.DB.prepare(
    "UPDATE users SET streak_current = ?, streak_best = ?, streak_freezes = ?, last_active_date = ? WHERE id = ?",
  )
    .bind(streakCurrent, streakBest, freezes, today, userId)
    .run();

  return { streak_current: streakCurrent, streak_best: streakBest, streak_freezes: freezes, freeze_consumed: freezeConsumed };
}

export interface ProfileUpdate {
  native_lang: string;
  target_lang: string;
  level: string;
  interests: string[];
  tutor_name: string;
  tutor_persona: string;
  tz: string;
  reminder_time?: string | null;
  daily_goal: number;
}

export async function updateProfile(env: Env, userId: string, update: ProfileUpdate): Promise<UserRow> {
  await env.DB.prepare(
    `UPDATE users SET
       native_lang = ?, target_lang = ?, level = ?, interests_json = ?,
       tutor_name = ?, tutor_persona = ?, tz = ?, reminder_time = ?, daily_goal = ?
     WHERE id = ?`,
  )
    .bind(
      update.native_lang,
      update.target_lang,
      update.level,
      JSON.stringify(update.interests),
      update.tutor_name,
      update.tutor_persona,
      update.tz,
      update.reminder_time ?? null,
      update.daily_goal,
      userId,
    )
    .run();

  const user = await getUser(env, userId);
  if (!user) throw new Error("user disappeared during profile update");
  return user;
}
