import { Hono } from "hono";
import type { Env } from "./env";
import { AppError, handleError, sendError } from "./errors";
import { authRoute } from "./routes/auth";
import { chatRoute } from "./routes/chat";
import { healthRoute } from "./routes/health";
import { profileRoute } from "./routes/profile";

const app = new Hono<{ Bindings: Env }>();

app.onError(handleError);
app.notFound((c) => sendError(c, new AppError("not_found", "No such route.")));

const v1 = new Hono<{ Bindings: Env }>();
v1.route("/health", healthRoute);
v1.route("/auth", authRoute); // POST /v1/auth/device is the only unauthenticated /v1 route
v1.route("/profile", profileRoute); // authenticate middleware applied inside profileRoute
v1.route("/chat", chatRoute); // authenticate middleware applied inside chatRoute

// tts, srs, daily, quiz, scenarios, vision, events routes land in M4+
// per CLAUDE.md build order.

app.route("/v1", v1);

export default app;
