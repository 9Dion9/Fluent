import type { Env } from "../env";

export interface EventInsert {
  name: string;
  props?: Record<string, unknown>;
  at: number;
}

/** Batched, fire-and-forget product analytics (CLAUDE.md §14) — never blocks the app. */
export async function insertEvents(env: Env, userId: string, events: EventInsert[]): Promise<void> {
  if (events.length === 0) return;

  const statements = events.map((e) =>
    env.DB.prepare("INSERT INTO events (id, user_id, name, props_json, created_at) VALUES (?, ?, ?, ?, ?)").bind(
      crypto.randomUUID(),
      userId,
      e.name,
      e.props ? JSON.stringify(e.props) : null,
      e.at,
    ),
  );
  await env.DB.batch(statements);
}
