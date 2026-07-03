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

**Not yet built:** quiz-item generation (`/v1/generate`), audio pre-rendering to R2.
The client already has a full TTS fallback chain (M4: Worker live-render + cache,
on-device `AVSpeechSynthesizer`), so daily words/SRS work without pre-rendered audio
— it's a cost optimization for later, not a blocker.
