# RUNBOOK.md — ops reference

> Updated as each node stands up (CLAUDE.md §15). Keep this current at the end of every milestone — a new session should be able to read this file top to bottom and know exactly where things stand without re-deriving anything from git log.

## Resume here (session continuity)

**Where we are:** M0 and M1 done and committed. M2's Worker/backend half (device auth, profile CRUD) is done. SETUP.md Parts A-C are done on the user's Mac (Xcode installed, Hello World running on a real iPhone 12). The repo is now pushed to GitHub (see "GitHub remote" below) so the Mac-created Xcode project can be merged in — that merge hasn't happened yet as of this writing. See the Milestone log at the bottom for full per-milestone detail.

## GitHub remote

Repo: **https://github.com/9Dion9/Fluent** (private). This box (`trading-ryzen`) pushes via a dedicated **deploy key** (write-enabled), not a personal token:
- Key: `~/.ssh/fluent_deploy_key` (ed25519, generated on this box, never leaves it)
- SSH config alias: `github-fluent` in `~/.ssh/config`, so remote URL is `github-fluent:9Dion9/Fluent.git` (not the usual `git@github.com:...` — the alias is what selects the right key)
- `git remote -v` on this box should show `origin` pointing at that alias URL
- The Mac side should use its own auth (the user's personal GitHub SSH key or HTTPS+PAT via `gh auth login` / Xcode's built-in GitHub account) — the deploy key is scoped to this box only

**Mac-side steps to merge the Xcode project in** (pending as of this writing):
1. On the Mac: `git clone https://github.com/9Dion9/Fluent.git ~/dev/fluent` (or wherever) — this pulls the real M0-M2 backend work
2. Move/copy the Xcode-created project (currently at `/Users/dion/Fluent` per the user's session) into `~/dev/fluent/app/` — i.e. the `.xcodeproj`, `Fluent/`, `FluentTests/`, `FluentUITests/` folders should end up at `~/dev/fluent/app/Fluent.xcodeproj` etc.
3. Re-open the project from its new location in Xcode (may need to re-confirm signing/team, bundle ID should be unchanged)
4. Confirm ⌘R still runs on the iPhone from the new path
5. `cd ~/dev/fluent && git add app/ && git commit -m "..." && git push`
6. This box then `git pull` to get `app/` and continue from here for future Swift work (the "filesystem-synchronized folder group" from SETUP.md B3 means new `.swift` files this agent creates will auto-appear in the Xcode target — but only true on the Mac; edits made here won't show live in Xcode until the user pulls)

**Live processes on this box (`trading-ryzen`) right now:**
- `fluent-gateway.service` (systemd, `Restart=always`) — the inference gateway, bound to `127.0.0.1:8000`. Check with `systemctl is-active fluent-gateway.service`.
- A manually-started `cloudflared tunnel --url http://localhost:8000 --protocol http2` background process exposing it at a `*.trycloudflare.com` URL. This is **not** systemd-managed and the URL **changes every time it's restarted** — check `ps aux | grep "cloudflared tunnel"`; if it's not running, restart it and grep its stdout log for the new URL, then update `GATEWAY_URL` in `infra/.dev.vars` (not `worker/.dev.vars` — `.dev.vars` location is relative to the `--config` file's directory; see the Secrets section gotcha below).
- **Process management gotcha:** `pkill -f "wrangler dev"` (and similar pattern-matched kills) have intermittently aborted the whole calling shell in this environment (observed exit code 144) instead of just killing the target. Prefer `ps aux | grep <name>` then `kill -9 <explicit pid>` for anything backgrounded here.

**Things a fresh session needs to know before touching infra:**
- `blockedordown.com` is an existing, unrelated Cloudflare zone on this account — **do not create DNS records, WAF rules, or tunnels against it.** (We tried once for the gateway tunnel, it fought back with bot protection, we abandoned and cleaned it up — see M1 log below.) Fluent has no production domain yet; that's a prerequisite for a stable tunnel, tracked as a TODO.
- `infra/wrangler.toml`'s committed `GATEWAY_URL` is a deliberately unroutable placeholder (`gateway.fluent.example.com`) so `worker`'s test suite has no live-network dependency. Never replace it with a real tunnel URL in a commit — override locally via `infra/.dev.vars` instead.
- No secrets are ever committed. `gateway/.env`, `infra/.dev.vars`, and the Cloudflare API token are all local-only / gitignored / never persisted to disk by the agent (see Secrets table below).
- This is a Linux box with no Xcode — the iOS `app/` directory does not exist in this repo yet. It gets created on the user's Mac per `SETUP.md` Part B and shares this same repo. Backend-only milestones (M0, M1, M5 batch, worker halves of M2-M4) can proceed here; SwiftUI work cannot.

**Quick health check when resuming:**
```bash
systemctl is-active fluent-gateway.service          # should be "active"
curl -s http://localhost:8000/healthz                # should be {"status":"ok","ollama":true}
ps aux | grep "cloudflared tunnel" | grep -v grep    # confirm quick tunnel still running, note its URL from its log
cd /srv/bots/Fluent/worker && npx vitest run          # should be all green
cd /srv/bots/Fluent/gateway && .venv/bin/pytest -q    # should be all green
cd /srv/bots/Fluent/shared && npx vitest run          # should be all green
git -C /srv/bots/Fluent log --oneline                 # see exactly what's committed so far
```

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

Set via `wrangler secret put <NAME> --config infra/wrangler.toml` (production) or `infra/.dev.vars` (local, gitignored — copy `infra/.dev.vars.example`).

**Important gotcha (cost real debugging time in M2): `.dev.vars` location is relative to the `--config` file's directory, not your cwd.** Since `wrangler dev` / the vitest test pool are always invoked with `--config ../infra/wrangler.toml`, the file must be `infra/.dev.vars` — a `worker/.dev.vars` is silently ignored (wrangler won't error, it just won't load it). The vitest suite doesn't read `.dev.vars` at all; its dummy `TOKEN_SIGNING_KEY`/`GATEWAY_SHARED_SECRET` are hardcoded directly in `worker/vitest.config.ts`'s `miniflare.bindings`.

| Secret | Used by | Status |
|---|---|---|
| `GATEWAY_SHARED_SECRET` | Worker -> gateway auth | **set**, matching value in both `gateway/.env` (home server, chmod 600) and `infra/.dev.vars` (local worker dev, gitignored). Not yet pushed to the Worker's production secret store — run `wrangler secret put GATEWAY_SHARED_SECRET --config infra/wrangler.toml` before deploying. |
| `TOKEN_SIGNING_KEY` | Worker bearer tokens (HMAC-SHA256 signing, CLAUDE.md §12) | **set locally** (`openssl rand -hex 32`, in `infra/.dev.vars`, gitignored). Not yet pushed to production — same `wrangler secret put` step as above before deploying. |
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
- Currently using a **quick tunnel** instead: `cloudflared tunnel --url http://localhost:8000 --protocol http2` (note: `--protocol http2` is required — this network's outbound QUIC/UDP 7844 is blocked, and plain `cloudflared tunnel --url` without a forced protocol hangs retrying QUIC). This prints a random `*.trycloudflare.com` hostname **every time it starts** — not committed to systemd (a `Restart=always` unit would silently break `GATEWAY_URL` on every restart), and **not baked into `infra/wrangler.toml`** either (that file's `GATEWAY_URL` default is deliberately the unroutable `gateway.fluent.example.com`, so `worker`'s test suite stays deterministic with no live network dependency). To point local `wrangler dev` at the real running gateway, set `GATEWAY_URL` in `infra/.dev.vars` (see the location gotcha in Secrets above) to whatever quick-tunnel URL is currently printed.
- **TODO before production (M8 or earlier):** get a dedicated domain for Fluent (not blockedordown.com), redo `cloudflared tunnel login` against it, recreate a named tunnel + systemd unit (deleted files: `infra/cloudflared/config.yml`, `infra/systemd/fluent-cloudflared.service` — recreate from the M1 commit history as a starting point), and update `GATEWAY_URL` to the stable hostname.

## Worker auth + profile (M2, backend half)

**Done — the Worker side of M2.** The iOS half (Theme.swift, onboarding UI) is separate and not started; see the note below.

- `POST /v1/auth/device` (`worker/src/routes/auth.ts`): create-or-verify anonymous device account. `{device_pubid, device_secret}` in, `{user_id, token}` out. First call for a `device_pubid` creates a `users` row with onboarding-pending defaults (`native_lang: en, target_lang: de, level: beginner, interests: [], tutor_name: "Tutor"`) + a `devices` row (`secret_hash = sha256(device_secret)`). Repeat calls verify the hash and return the same `user_id`; a mismatched secret is a 401, not a new account. Rate limited 20/IP/hour via the new generic `worker/src/rateLimit.ts` KV fixed-window helper (reusable for the chat/TTS/camera limits in CLAUDE.md §13 later).
- Bearer token (`worker/src/crypto.ts`): opaque `${userId}.${issuedAt}.${sig}` via WebCrypto HMAC-SHA256, exactly per CLAUDE.md §12 — no JWT library. Verified with a timing-safe compare. No expiry in v1; revocation is a KV denylist keyed `auth:denylist:<token>` (denylist-writing isn't wired to any route yet — no logout/revoke endpoint exists in v1 scope, but the seam is there).
- `worker/src/middleware/authenticate.ts`: Hono middleware requiring `Authorization: Bearer <token>`, sets `c.set("userId", ...)`. Applied to every `/v1/profile/*` route; `/v1/auth/device` is the only unauthenticated `/v1` route (mirrors the CLAUDE.md §6 contract).
- `GET /v1/profile` / `PUT /v1/profile` (`worker/src/routes/profile.ts`): read/update the onboarding fields + streak fields. `PUT` validates against `profileUpdateSchema` (zod, `worker/src/schemas.ts`).
- `worker/src/repos/users.ts`: all `users`/`devices` D1 queries live here, not inline in routes.
- 10 new vitest tests (create, repeat-auth same user_id, wrong-secret 401, malformed body 400, rate-limit 429, profile defaults, PUT+GET round-trip, invalid PUT 400, no-token 401, tampered-token 401) — all passing, plus the pre-existing 2. Test D1 now gets real migrations applied via a `setupFiles` hook (`worker/test/apply-migrations.ts` + `readD1Migrations` in `vitest.config.ts`) — previously the isolated test database had no tables at all and every D1-touching test would have failed.
- Live-verified against local D1 through `wrangler dev` (not just the test suite): registered a device, fetched onboarding-pending defaults, PUT a full onboarding payload, confirmed GET reflects it, confirmed repeat-auth returns the same `user_id`, confirmed wrong-secret and no-token are both rejected. Test rows cleaned out of local D1 afterward.

**iOS half of M2 is NOT started.** This box has no Xcode — the `app/` Xcode project doesn't exist in this repo yet (per `SETUP.md` Part B, it's created on your Mac and shares this repo). `Theme.swift` (DESIGN.md tokens + core components) and the full onboarding flow (DESIGN.md §9, incl. adaptive placement) are still pending and can only be built once `app/` exists. The M2 CLAUDE.md verify step ("fresh install -> onboarded profile row in D1; onboarding feels like DESIGN.md") is only partially checkable right now — the backend half is verified (a fresh device really does get an onboarded profile row via the API), but the actual SwiftUI onboarding UX can't be judged without the app.

## Hetzner CX23 control node

Not yet provisioned — Milestone 5/8 (batch cron, D1 backups, health monitor -> ntfy.sh).

## Piper TTS voices

- German: `de_DE-thorsten-high`
- English: `en_US-lessac-high`

Fetched by `gateway/scripts/setup_piper.sh` (binary + both voice models are gitignored — large downloaded artifacts, not source).

## Local dev

```bash
cd infra && cp .dev.vars.example .dev.vars   # then fill in real values (see Secrets above)
cd worker && npm install && npm run dev     # wrangler dev — reads ../infra/.dev.vars, NOT worker/.dev.vars
cd worker && npm test                        # vitest — migrations auto-applied to isolated test D1
cd shared && npm install && npm test         # schema round-trip fixtures
cd infra && ./migrate.sh --local             # apply migrations to local D1

cd gateway && python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
cd gateway && ./scripts/setup_piper.sh       # downloads Piper binary + voices (gitignored)
cd gateway && cp .env.example .env           # then fill in GATEWAY_SHARED_SECRET
cd gateway && make dev                       # uvicorn, needs gateway/.env
cd gateway && make test                      # pytest, mocked Ollama/Piper
```

**Manual end-to-end check for the auth+profile flow** (what was used to verify M2's backend half — useful to re-run after touching auth code):
```bash
# with wrangler dev running on :8787
curl -s -X POST http://localhost:8787/v1/auth/device -H "Content-Type: application/json" \
  -d '{"device_pubid":"test-1","device_secret":"my-secret"}'
# -> {"user_id": "...", "token": "..."}  — save the token
curl -s http://localhost:8787/v1/profile -H "Authorization: Bearer <token>"
# -> onboarding-pending defaults
curl -s -X PUT http://localhost:8787/v1/profile -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -d '{"native_lang":"en","target_lang":"de","level":"elementary","interests":["travel"],"tutor_name":"Emma","tutor_persona":"sunny","tz":"Europe/Berlin","reminder_time":"19:00","daily_goal":10}'
# re-POST /v1/auth/device with the same device_pubid + secret -> same user_id
# clean up test rows afterward: wrangler d1 execute fluent-db --local --command "DELETE FROM devices WHERE id='test-1'; DELETE FROM users WHERE id='<user_id>'"
```

## Milestone log

- **M0 (scaffold & contracts):** done. Repo layout, `/shared` schemas + fixtures, Worker skeleton (`/v1/health`, error contract), D1 migration `0001_init.sql`. Gateway does not exist yet, so `/v1/health` correctly reports `gateway: "down"`. Cloudflare resources (D1/KV/R2) created and migration applied local + remote.
- **M1 (inference gateway):** done. FastAPI gateway (`/healthz`, `/v1/chat`, `/v1/tts`) live on this box, systemd-managed, `X-Gateway-Secret`-protected. Verified end-to-end through a public tunnel: Worker's `/v1/health` reports `gateway: "ok"`, and a real chat completion + TTS render (valid `.m4a`) both round-tripped through the tunnel from outside the box. Public exposure is a dev-only quick tunnel pending a dedicated domain — see above.
- **M2 (auth + onboarding + design foundation) — backend half done, iOS half not started.** `POST /v1/auth/device`, `GET`/`PUT /v1/profile`, HMAC bearer tokens, auth middleware — see "Worker auth + profile" section above for full detail. 12 new/updated vitest tests passing, live-verified through `wrangler dev` against local D1. `Theme.swift` and the full DESIGN.md §9 onboarding flow need the iOS `app/` project, which doesn't exist on this Linux box yet — that's the next concrete blocker (needs the user's Mac, `SETUP.md` Part B).
