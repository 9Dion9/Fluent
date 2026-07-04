import { Hono } from "hono";
import type { Env } from "../env";
import { AppError } from "../errors";
import { authenticate } from "../middleware/authenticate";
import { getUser } from "../repos/users";
import { getRandomQuiz } from "../repos/quiz";
import { difficultyForLevel } from "../cefr";

export const quizRoute = new Hono<{ Bindings: Env }>();
quizRoute.use("*", authenticate);

quizRoute.get("/next", async (c) => {
  const env = c.env;
  const userId = c.get("userId") as string;
  const user = await getUser(env, userId);
  if (!user) throw new AppError("unauthorized", "No such user.");

  const typesParam = c.req.query("types");
  const types = typesParam ? typesParam.split(",").map((t) => t.trim()) : [];

  const quiz = await getRandomQuiz(env, user.target_lang, types, difficultyForLevel(user.level));
  if (!quiz) {
    throw new AppError("not_found", "No quizzes available yet for your level.");
  }

  return c.json({
    id: quiz.id,
    lang: quiz.lang,
    type: quiz.type,
    prompt: JSON.parse(quiz.prompt_json),
    answer: JSON.parse(quiz.answer_json),
    difficulty: quiz.difficulty,
    word_ids: quiz.word_ids_json ? JSON.parse(quiz.word_ids_json) : [],
  });
});
