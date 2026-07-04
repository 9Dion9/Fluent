# batch

Python batch content pipeline (CLAUDE.md §3, M5). Run from this directory.

```bash
python3 -m venv .venv && .venv/bin/pip install httpx
.venv/bin/python -m batch.run seed_words --lang de --top-n 3000 [--dry-run]
.venv/bin/python -m batch.run seed_words --lang en --top-n 3000 [--dry-run]
```

## seed_words

Seeds `content_words` from two open-data sources per CLAUDE.md §3 — deterministic
facts, never LLM-invented:

- **Frequency ranking**: [Hermit Dave's FrequencyWords](https://github.com/hermitdave/FrequencyWords)
  (OpenSubtitles-derived), top N words per language, cached in `.cache/`.
- **Gender/POS/IPA/translation/example**: [kaikki.org](https://kaikki.org) wiktextract
  JSONL dumps (1-3GB each, streamed — never downloaded to disk). See `wiktextract.py`
  for the sense-disambiguation logic (homograph resolution, filtering grammatical
  "inflection of X" descriptions out of what should be a translation, etc.) and its
  extensive comments — Wiktionary extraction has real, documented rough edges.

Deliberate deviation from the CLAUDE.md §3 sketch: example sentences + their
translations come straight from Wiktionary (already present in the dumps we're
reading anyway) rather than a separate LLM generation pass. Strictly higher quality
than inventing one.

Output: `output/seed_words_{lang}.sql` (idempotent — `ON CONFLICT(lang,word) DO
UPDATE`, safe to re-run) and `.jsonl` (for inspection/debugging). Apply with:

```bash
cd ../infra
npx wrangler d1 execute fluent-db --config wrangler.toml --local --file=../batch/output/seed_words_de.sql
# --remote for production — ask before running against prod from an unattended session
```

**Known data-quality limitation:** homograph sense selection (which meaning of a
word with multiple parts of speech / multiple noun senses gets picked) is a best-
effort heuristic (POS priority for closed-class words, sense-richness for open-class
ties), not perfect — Wiktionary doesn't expose sense-frequency data. A handful of
manually-verified overrides exist in `wiktextract.py` for spotted bad cases (e.g.
German "Mutter" defaulting to "nut (for a bolt)" instead of "mother"); more will
surface with use. `content_words.verified` is `1` for everything here since
gender/POS/IPA themselves are genuinely Wiktionary-sourced, not LLM-invented — it
does not mean "human-reviewed for translation accuracy."

**Not yet built:** audio pre-rendering to R2. The client already has a full TTS
fallback chain (M4: Worker live-render + cache, on-device `AVSpeechSynthesizer`), so
daily words/SRS work without pre-rendered audio — it's a cost optimization for
later, not a blocker.

## quiz_gen

Seeds `quizzes` per `shared/schemas/quiz.json`'s documented shape (M6). Run after
`seed_words` for the same language — it reads that job's `.jsonl` output:

```bash
.venv/bin/python -m batch.run quiz_gen --lang de --mcq-count 100 [--dry-run]
```

Three of the four quiz types are built **deterministically from already
Wiktionary-verified data — zero LLM cost, zero hallucination risk**:
- `match`: groups of 4 words paired against their (shuffled) translations.
- `fillblank`: the word blanked out of its own real Wiktionary example sentence.
- `order`: a real example sentence's words shuffled, user rebuilds it.

Only `mcq` genuinely needs the LLM (`gpt-oss:20b`, CLAUDE.md §3's batch model) — the
data doesn't provide plausible *wrong* answer options, which is what multiple-choice
needs. Deliberate simplification vs. CLAUDE.md §3's sketch: reuses the gateway's
existing generic `/v1/chat` (with a `model` override) instead of standing up a
separate `/v1/generate` endpoint — `/v1/chat` was already generic enough, so a
near-duplicate route would have been pure overhead.

Reads `GATEWAY_SHARED_SECRET` straight from `infra/.dev.vars` and calls
`http://127.0.0.1:8000` directly (this job runs on the same box as the gateway,
unlike the Worker which goes through the tunnel) — no `X-Gateway-Secret` handling
needed beyond that.

Idempotent the same way as `seed_words`: `content_hash` is deterministic
(`sha256(lang:type:word_id(s))`), `ON CONFLICT(content_hash) DO UPDATE`.

## vision_labels

Seeds `vision_labels` (M7, CLAUDE.md §9) — maps Vision-classifier-style labels to
Wiktionary-verified `content_words`, so the camera lens's instant path (no gateway
call) works for common household objects out of the box:

```bash
.venv/bin/python -m batch.run vision_labels --lang de [--dry-run]
.venv/bin/python -m batch.run vision_labels --lang en [--dry-run]
```

**Curated, not exhaustive** — ~65 common household/office objects (cup, chair,
table, phone, laptop, key, ...), each hand-mapped to its target-language word
(e.g. "cup" -> "Tasse"). Apple's on-device classifier vocabulary isn't public, so
there's no way to auto-generate a complete label list; this covers what's likely to
come up in early manual testing. Gender/POS/IPA for each chosen word still come
straight from Wiktionary via `stream_matching_entries` — same as `seed_words` — only
the *which German word means "cup"* judgment call is manual, since the pipeline has
no bilingual dictionary source to automate that.

Everything this list misses falls through to the Gemma VLM fallback
(`POST /v1/vision/identify` on the Worker, `POST /v1/vision` on the gateway) at
request time — and a correct fallback identification **self-caches** into
`vision_labels` for next time (see `worker/src/repos/vision.ts`
`upsertVisionLabelMapping`), so real usage grows the instant-path coverage over time
without another batch run.

Output: `output/vision_labels_{lang}.sql` — inserts/updates `content_words` the same
idempotent way as `seed_words` (`ON CONFLICT(lang,word) DO UPDATE`), then maps each
label via a `SELECT id FROM content_words WHERE lang=... AND word=...` subquery
(not a hardcoded id) so it resolves correctly even if the word already existed from
an earlier `seed_words` run under a different row id.

**Bug found and fixed while building this**: `wiktextract.py`'s cheap regex
prefilter (`_WORD_FIELD_RE.search(line)`, before the `dry-run` mismatch) matched
only the *first* `"word":` occurrence in a JSONL line — but many entries list
`"descendants"`/`"derived"`/`"related"` (each containing their own nested `"word"`
keys) *before* the entry's own top-level `"word"` field in kaikki's serialization
order. That silently dropped legitimate words whose entry happened to have such a
list first (e.g. "Tasse" has Finnish/Polish/Latvian descendants listed before its
own `"word": "Tasse"`, so the old code matched "tassi" instead and dropped the real
entry). Fixed to `findall` + verify against the authoritative `data.get("word")`
after parsing. This means `seed_words`'s M5 output for both languages was very
likely a strict undercount (dropped some legitimate frequency-list words) — not
wrong data, just incomplete. Re-running `seed_words` with the fix would very likely
add previously-missed words; not done automatically since M5's data is already live
in production and re-seeding + re-pushing is a call for whoever's running the
pipeline, not an automatic side effect of an unrelated M7 change.

## report

Weekly retention/funnel report (M8, CLAUDE.md §14):

```bash
.venv/bin/python -m batch.run report --days 7          # local D1
.venv/bin/python -m batch.run report --days 7 --remote  # production D1
```

Prints funnel event counts + distinct users for the tracked events
(`onboarding_step`, `placement_done`, `first_chat_turn`, `chat_turn`,
`daily_completed`, `review_done`, `camera_snap`, `streak_day`), a simple
"active on 2+ distinct days" retention proxy, and streak distribution across
users. Reads via `wrangler d1 execute --json` — same tool every other D1
read/write in this project already uses, so no separate Cloudflare REST API
client was wired up just for this.
