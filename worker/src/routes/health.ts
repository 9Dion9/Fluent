import { Hono } from "hono";
import type { Env } from "../env";
import { checkGatewayHealth } from "../gateway";

export const healthRoute = new Hono<{ Bindings: Env }>();

healthRoute.get("/", async (c) => {
  const gateway = await checkGatewayHealth(c.env);
  return c.json({ worker: "ok" as const, gateway });
});
