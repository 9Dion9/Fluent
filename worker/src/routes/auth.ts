import { Hono } from "hono";
import type { Env } from "../env";
import { deviceAuthRequestSchema } from "../schemas";
import { AppError, sendError } from "../errors";
import { sha256Hex, signToken } from "../crypto";
import { isRateLimited } from "../rateLimit";
import { createUserWithDevice, findDevice, touchDeviceLastSeen } from "../repos/users";

export const authRoute = new Hono<{ Bindings: Env }>();

const DEVICE_AUTH_LIMIT_PER_HOUR = 20;

authRoute.post("/device", async (c) => {
  const ip = c.req.header("CF-Connecting-IP") ?? "unknown";
  if (await isRateLimited(c.env, `auth_device:${ip}`, DEVICE_AUTH_LIMIT_PER_HOUR, 3600)) {
    return sendError(c, new AppError("rate_limited", "Too many auth attempts — try again later.", { retryable: true }));
  }

  const parsed = deviceAuthRequestSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) {
    return sendError(c, new AppError("invalid_request", "device_pubid and device_secret are required."));
  }
  const { device_pubid, device_secret } = parsed.data;
  const secretHash = await sha256Hex(device_secret);
  const now = Date.now();

  const existing = await findDevice(c.env, device_pubid);

  let userId: string;
  if (existing) {
    if (existing.secret_hash !== secretHash) {
      return sendError(c, new AppError("unauthorized", "Device secret does not match."));
    }
    await touchDeviceLastSeen(c.env, device_pubid, now);
    userId = existing.user_id;
  } else {
    const user = await createUserWithDevice(c.env, device_pubid, secretHash, now);
    userId = user.id;
  }

  const token = await signToken(userId, now, c.env.TOKEN_SIGNING_KEY);
  return c.json({ user_id: userId, token });
});
