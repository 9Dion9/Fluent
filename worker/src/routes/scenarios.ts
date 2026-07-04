import { Hono } from "hono";
import type { Env } from "../env";
import { AppError } from "../errors";
import { authenticate } from "../middleware/authenticate";
import { getUser } from "../repos/users";
import { listScenarios } from "../repos/conversations";
import { cefrsUpTo, LEVEL_CEFR_CEILING } from "../cefr";

export const scenariosRoute = new Hono<{ Bindings: Env }>();
scenariosRoute.use("*", authenticate);

scenariosRoute.get("/", async (c) => {
  const env = c.env;
  const userId = c.get("userId") as string;
  const user = await getUser(env, userId);
  if (!user) throw new AppError("unauthorized", "No such user.");

  const ceiling = LEVEL_CEFR_CEILING[user.level] ?? "A2";
  const rows = await listScenarios(env, user.target_lang, cefrsUpTo(ceiling));

  return c.json(
    rows.map((r) => ({
      id: r.id,
      lang: r.lang,
      title: r.title,
      emoji: r.emoji,
      min_level: r.min_level,
      seed_prompt: r.seed_prompt,
      focus_word_ids: r.focus_word_ids_json ? JSON.parse(r.focus_word_ids_json) : [],
    })),
  );
});
