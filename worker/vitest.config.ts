import path from "node:path";
import { defineWorkersConfig, readD1Migrations } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig(async () => {
  const migrationsPath = path.join(__dirname, "../infra/migrations");
  const migrations = await readD1Migrations(migrationsPath);

  return {
    test: {
      setupFiles: ["./test/apply-migrations.ts"],
      poolOptions: {
        workers: {
          wrangler: { configPath: "../infra/wrangler.toml" },
          miniflare: {
            bindings: {
              TEST_MIGRATIONS: migrations,
              // Test-only dummy values — vitest-pool-workers doesn't read worker/.dev.vars.
              TOKEN_SIGNING_KEY: "test-signing-key",
              GATEWAY_SHARED_SECRET: "test-gateway-secret",
              // Deliberately unroutable so tests stay deterministic with no live
              // network dependency (GATEWAY_URL moved from [vars] to a real secret
              // in production — see infra/wrangler.toml).
              GATEWAY_URL: "https://gateway.fluent.example.com",
            },
          },
        },
      },
    },
  };
});
