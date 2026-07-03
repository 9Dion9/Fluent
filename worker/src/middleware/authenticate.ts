import type { Context, Next } from "hono";
import type { Env } from "../env";
import { verifyToken } from "../crypto";
import { AppError, sendError } from "../errors";

declare module "hono" {
  interface ContextVariableMap {
    userId: string;
  }
}

const DENYLIST_PREFIX = "auth:denylist:";

/** Applies to every /v1 route except POST /v1/auth/device (CLAUDE.md §6). */
export async function authenticate(c: Context<{ Bindings: Env }>, next: Next) {
  const header = c.req.header("Authorization");
  const token = header?.startsWith("Bearer ") ? header.slice("Bearer ".length) : null;
  if (!token) {
    return sendError(c, new AppError("unauthorized", "Missing bearer token."));
  }

  const claims = await verifyToken(token, c.env.TOKEN_SIGNING_KEY);
  if (!claims) {
    return sendError(c, new AppError("unauthorized", "Invalid or expired token."));
  }

  const denied = await c.env.KV.get(`${DENYLIST_PREFIX}${token}`);
  if (denied) {
    return sendError(c, new AppError("unauthorized", "Token has been revoked."));
  }

  c.set("userId", claims.userId);
  await next();
}
