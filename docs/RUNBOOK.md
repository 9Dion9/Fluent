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
| `GATEWAY_SHARED_SECRET` | Worker -> gateway auth | **set.** Generated with `openssl rand -hex 32`, lives in `gateway/.env` (chmod 600, gitignored) on the home server. Not yet pushed to the Worker's production secret store — run `wrangler secret put GATEWAY_SHARED_SECRET --config infra/wrangler.toml` with the same value before deploying. |
| `TOKEN_SIGNING_KEY` | Worker bearer tokens | not set — needed in M2 |
| Cloudflare API token | batch pipeline (Hetzner) | not persisted anywhere; export fresh when needed |

## Inference gateway (home server = this box, `trading-ryzen`)

**Stood up in M1.** FastAPI (`gateway/app`) wrapping Ollama + Piper + ffmpeg.

- Hardware: RTX 5060 Ti 16GB. Ollama already had `qwen3:14b`, `gpt-oss:20b`, `gemma4:12b` pulled.
- `qwen3:14b` non-thinking mode confirmed working via Ollama's native `think: false` chat param (Ollama 0.30.8) — no `/no_think` prompt hack needed.
- `keep_alive` is controlled per-request (gateway defaults chat requests to `-1`/resident) rather than via a static `OLLAMA_KEEP_ALIVE` systemd env var, so the batch pipeline (M5) can swap in `gpt-oss:20b` with `keep_alive: 0` and re-warm qwen3 afterward without restarting Ollama.
- TTS: **Piper's Python package is broken on Python 3.12** (`piper-phonemize` has no wheel). Using the official prebuilt binary from `rhasspy/piper` GitHub releases instead (`gateway/bin/piper/`, gitignored, fetched via `gateway/scripts/setup_piper.sh`). Gateway shells out to it, then pipes through `ffmpeg` for AAC transcode. Verified end-to-end: Piper WAV -> ffmpeg -> valid `.m4a`.
- Voices downloaded (gitignored, `gateway/voices/`, fetched by the same setup script): `de_DE-thorsten-high`, `en_US-lessac-high`.
- Endpoints: `GET /healthz` (open), `POST /v1/chat`, `POST /v1/tts` (both require `X-Gateway-Secret`). `/v1/vision` and `/v1/generate` are out of scope until M7/M5.
- 12/12 pytest tests pass (mocked Ollama/Piper). Live smoke test against the real GPU: chat round-trip ~3s (within the p95 < 6s budget), TTS produces valid `audio/mp4`.
- Runs as systemd unit `fluent-gateway.service` (`infra/systemd/fluent-gateway.service`, installed at `/etc/systemd/system/`), `Restart=always`, bound to `127.0.0.1:8000` only (not exposed directly — tunnel is the only path in).

### Public exposure: tunnel is dev-only right now, not production-stable

- Tried a **named Cloudflare Tunnel** on `gateway-fluent.blockedordown.com` (the only domain on the account) — blocked at multiple layers by that zone's bot protection (Managed Challenge survived both a WAF custom-rule skip and a Configuration Rule forcing Security Level off, almost certainly Bot/Super Bot Fight Mode, which has no clean per-hostname bypass). **Abandoned** — the named tunnel, its DNS CNAME, the WAF custom rule, and the Configuration Rule were all deleted; `blockedordown.com` was left otherwise untouched per explicit instruction to keep Fluent fully separate from that project.
- Currently using a **quick tunnel** instead: `cloudflared tunnel --url http://localhost:8000 --protocol http2` (note: `--protocol http2` is required — this network's outbound QUIC/UDP 7844 is blocked, and plain `cloudflared tunnel --url` without a forced protocol hangs retrying QUIC). This prints a random `*.trycloudflare.com` hostname **every time it starts** — not committed to systemd (a `Restart=always` unit would silently break `GATEWAY_URL` on every restart), and **not baked into `infra/wrangler.toml`** either (that file's `GATEWAY_URL` default is deliberately the unroutable `gateway.fluent.example.com`, so `worker`'s test suite stays deterministic with no live network dependency). To point local `wrangler dev` at the real running gateway, set `GATEWAY_URL` in `worker/.dev.vars` to whatever quick-tunnel URL is currently printed.
- **TODO before production (M8 or earlier):** get a dedicated domain for Fluent (not blockedordown.com), redo `cloudflared tunnel login` against it, recreate a named tunnel + systemd unit (deleted files: `infra/cloudflared/config.yml`, `infra/systemd/fluent-cloudflared.service` — recreate from the M1 commit history as a starting point), and update `GATEWAY_URL` to the stable hostname.

## Hetzner CX23 control node

Not yet provisioned — Milestone 5/8 (batch cron, D1 backups, health monitor -> ntfy.sh).

## Piper TTS voices

- German: `de_DE-thorsten-high`
- English: `en_US-lessac-high`

Fetched by `gateway/scripts/setup_piper.sh` (binary + both voice models are gitignored — large downloaded artifacts, not source).

## Local dev

```bash
cd worker && npm install && npm run dev     # wrangler dev, needs worker/.dev.vars
cd worker && npm test                        # vitest against local D1/KV bindings
cd shared && npm install && npm test         # schema round-trip fixtures
cd infra && ./migrate.sh --local             # apply migrations to local D1

cd gateway && python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
cd gateway && ./scripts/setup_piper.sh       # downloads Piper binary + voices (gitignored)
cd gateway && cp .env.example .env           # then fill in GATEWAY_SHARED_SECRET
cd gateway && make dev                       # uvicorn, needs gateway/.env
cd gateway && make test                      # pytest, mocked Ollama/Piper
```

## Milestone log

- **M0 (scaffold & contracts):** done. Repo layout, `/shared` schemas + fixtures, Worker skeleton (`/v1/health`, error contract), D1 migration `0001_init.sql`. Gateway does not exist yet, so `/v1/health` correctly reports `gateway: "down"`. Cloudflare resources (D1/KV/R2) created and migration applied local + remote.
- **M1 (inference gateway):** done. FastAPI gateway (`/healthz`, `/v1/chat`, `/v1/tts`) live on this box, systemd-managed, `X-Gateway-Secret`-protected. Verified end-to-end through a public tunnel: Worker's `/v1/health` reports `gateway: "ok"`, and a real chat completion + TTS render (valid `.m4a`) both round-tripped through the tunnel from outside the box. Public exposure is a dev-only quick tunnel pending a dedicated domain — see above.
