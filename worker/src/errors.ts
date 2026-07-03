import type { Context } from "hono";
import { z } from "zod";

export const ERROR_CODES = [
  "unauthorized",
  "invalid_request",
  "rate_limited",
  "tutor_napping",
  "not_found",
  "internal",
] as const;

export type ErrorCode = (typeof ERROR_CODES)[number];

const STATUS_BY_CODE: Record<ErrorCode, number> = {
  unauthorized: 401,
  invalid_request: 400,
  rate_limited: 429,
  tutor_napping: 503,
  not_found: 404,
  internal: 500,
};

export const errorResponseSchema = z.object({
  error: z.object({
    code: z.enum(ERROR_CODES),
    message: z.string(),
    retryable: z.boolean(),
  }),
});

export type ErrorResponse = z.infer<typeof errorResponseSchema>;

/** Every non-2xx response the Worker returns must be an AppError, so the shape is always the error contract. */
export class AppError extends Error {
  readonly code: ErrorCode;
  readonly retryable: boolean;
  readonly status: number;

  constructor(code: ErrorCode, message: string, opts: { retryable?: boolean } = {}) {
    super(message);
    this.code = code;
    this.retryable = opts.retryable ?? false;
    this.status = STATUS_BY_CODE[code];
  }

  toResponse(): ErrorResponse {
    return { error: { code: this.code, message: this.message, retryable: this.retryable } };
  }
}

export function sendError(c: Context, err: AppError) {
  return c.json(err.toResponse(), err.status as 400 | 401 | 403 | 404 | 429 | 500 | 503);
}

/** Hono onError handler — guarantees the error contract even for unexpected throws. */
export function handleError(err: unknown, c: Context) {
  if (err instanceof AppError) {
    return sendError(c, err);
  }
  console.error(JSON.stringify({ msg: "unhandled_error", error: String(err) }));
  return sendError(c, new AppError("internal", "Something went wrong on our end."));
}
