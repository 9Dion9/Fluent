import { SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";

describe("GET /v1/health", () => {
  it("reports worker ok and gateway down when no gateway is reachable", async () => {
    const res = await SELF.fetch("https://worker.test/v1/health");
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body).toEqual({ worker: "ok", gateway: "down" });
  });
});

describe("unknown routes", () => {
  it("returns the error contract shape on 404", async () => {
    const res = await SELF.fetch("https://worker.test/v1/does-not-exist");
    expect(res.status).toBe(404);
    const body = await res.json();
    expect(body).toEqual({
      error: { code: "not_found", message: "No such route.", retryable: false },
    });
  });
});
