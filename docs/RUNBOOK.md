# RUNBOOK.md — ops reference

> Updated as each node stands up (CLAUDE.md §15). M0 status below.

## Cloudflare resources

| Resource | Name | Status |
|---|---|---|
| D1 database | `fluent-db` | created, region WEUR, id `a51eea4d-cdf5-4795-a95c-bf7ea90be90f`. Migration `0001_init.sql` applied local + remote. |
| KV namespace | `fluent-kv` | created, id `9d59d484186445a3b90063516c8d3629` |
| R2 bucket | `fluent-audio` | created, default Standard storage class |
| Worker | `fluent-worker` | scaffolded (M0), not deployed |

All three IDs are filled into `infra/wrangler.toml`.

Account auth: a Cloudflare API token (Edit Cloudflare Workers template + Account/D1/Edit added) was used one-off to create these resources and apply migrations. It was never written to disk or committed — set your own `CLOUDFLARE_API_TOKEN` env var when you need to run `wrangler` against the remote account again (e.g. future `wrangler deploy`, `wrangler secret put`, or remote migrations).

## Secrets

Set via `wrangler secret put <NAME> --config infra/wrangler.toml` (production) or `worker/.dev.vars` (local, gitignored — copy `worker/.dev.vars.example`).

| Secret | Used by | Status |
|---|---|---|
| `GATEWAY_SHARED_SECRET` | Worker -> gateway auth | not set — needed in M1 |
| `TOKEN_SIGNING_KEY` | Worker bearer tokens | not set — needed in M2 |
| Cloudflare API token | batch pipeline (Hetzner) | not persisted anywhere; export fresh when needed |

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

- **M0 (scaffold & contracts):** done. Repo layout, `/shared` schemas + fixtures, Worker skeleton (`/v1/health`, error contract), D1 migration `0001_init.sql`. Gateway does not exist yet, so `/v1/health` correctly reports `gateway: "down"`. Cloudflare resources (D1/KV/R2) created and migration applied local + remote.
