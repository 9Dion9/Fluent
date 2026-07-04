import { Hono } from "hono";
import type { Env } from "./env";
import { AppError, handleError, sendError } from "./errors";
import { audioRoute } from "./routes/audio";
import { authRoute } from "./routes/auth";
import { chatRoute } from "./routes/chat";
import { dailyRoute } from "./routes/daily";
import { eventsRoute } from "./routes/events";
import { healthRoute } from "./routes/health";
import { profileRoute } from "./routes/profile";
import { quizRoute } from "./routes/quiz";
import { scenariosRoute } from "./routes/scenarios";
import { srsRoute } from "./routes/srs";
import { ttsRoute } from "./routes/tts";
import { visionRoute } from "./routes/vision";

const app = new Hono<{ Bindings: Env }>();

app.onError(handleError);
app.notFound((c) => sendError(c, new AppError("not_found", "No such route.")));

const v1 = new Hono<{ Bindings: Env }>();
v1.route("/health", healthRoute);
v1.route("/auth", authRoute); // POST /v1/auth/device is the only unauthenticated /v1 route
v1.route("/profile", profileRoute); // authenticate middleware applied inside profileRoute
v1.route("/chat", chatRoute); // authenticate middleware applied inside chatRoute
v1.route("/tts", ttsRoute); // authenticate middleware applied inside ttsRoute
v1.route("/audio", audioRoute); // deliberately unauthenticated — see routes/audio.ts
v1.route("/srs", srsRoute); // authenticate middleware applied inside srsRoute
v1.route("/daily", dailyRoute); // authenticate middleware applied inside dailyRoute
v1.route("/quiz", quizRoute); // authenticate middleware applied inside quizRoute
v1.route("/vision", visionRoute); // authenticate middleware applied inside visionRoute
v1.route("/events", eventsRoute); // authenticate middleware applied inside eventsRoute
v1.route("/scenarios", scenariosRoute); // authenticate middleware applied inside scenariosRoute

app.route("/v1", v1);

export default app;
