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
