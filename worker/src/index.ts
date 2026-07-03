import { Hono } from "hono";
import type { Env } from "./env";
import { AppError, handleError, sendError } from "./errors";
import { healthRoute } from "./routes/health";

const app = new Hono<{ Bindings: Env }>();

app.onError(handleError);
app.notFound((c) => sendError(c, new AppError("not_found", "No such route.")));

const v1 = new Hono<{ Bindings: Env }>();
v1.route("/health", healthRoute);

// Auth, profile, chat, tts, srs, daily, quiz, scenarios, vision, events routes
// land in M2+ per CLAUDE.md build order — /v1/health is the only route M0 requires.

app.route("/v1", v1);

export default app;
