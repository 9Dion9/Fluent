# RUNBOOK.md — ops reference

> Updated as each node stands up (CLAUDE.md §15). M0 status below.

## Cloudflare resources

| Resource | Name | Status |
|---|---|---|
| D1 database | `fluent-db` | **not yet created** — run `wrangler d1 create fluent-db`, paste the returned `database_id` into `infra/wrangler.toml` |
| KV namespace | `fluent-kv` | **not yet created** — run `wrangler kv namespace create fluent-kv`, paste the `id` into `infra/wrangler.toml` |
| R2 bucket | `fluent-audio` | **not yet created** — run `wrangler r2 bucket create fluent-audio` |
| Worker | `fluent-worker` | scaffolded (M0), not deployed |

## Secrets

Set via `wrangler secret put <NAME> --config infra/wrangler.toml` (production) or `worker/.dev.vars` (local, gitignored — copy `worker/.dev.vars.example`).

| Secret | Used by | Status |
|---|---|---|
| `GATEWAY_SHARED_SECRET` | Worker -> gateway auth | not set |
| `TOKEN_SIGNING_KEY` | Worker bearer tokens | not set |
| Cloudflare API token | batch pipeline (Hetzner) | not set |

## Inference gateway (home server)

Not yet stood up — Milestone 1. Target: FastAPI + Ollama + Piper + ffmpeg, exposed via `cloudflared` tunnel, `GATEWAY_URL` in `infra/wrangler.toml` points at the tunnel hostname.

## Hetzner CX23 control node

Not yet provisioned — Milestone 5/8 (batch cron, D1 backups, health monitor -> ntfy.sh).

## Piper TTS voices

Recorded per language once chosen in M1:
- German: `de_DE-thorsten-high`
- English: `en_US-lessac-high` (or best available `en_GB` high)

## Local dev

```bash
cd worker && npm install && npm run dev     # wrangler dev, needs worker/.dev.vars
cd worker && npm test                        # vitest against local D1/KV bindings
cd shared && npm install && npm test         # schema round-trip fixtures
cd infra && ./migrate.sh --local             # apply migrations to local D1
```

## Milestone log

- **M0 (scaffold & contracts):** done. Repo layout, `/shared` schemas + fixtures, Worker skeleton (`/v1/health`, error contract), D1 migration `0001_init.sql`. Gateway does not exist yet, so `/v1/health` correctly reports `gateway: "down"`.
