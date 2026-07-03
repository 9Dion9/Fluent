"""content_words seeding job (CLAUDE.md §3, M5). Idempotent/resumable: content_words
has UNIQUE(lang, word) and each row's id is deterministic (sha256 of lang+word), so
re-running this job with `INSERT OR REPLACE` never produces duplicates or drifts ids.

Deliberate deviation from the CLAUDE.md §3 sketch: example/example_translation come
straight from Wiktionary (real, human-written, already available in the same dump we're
reading for gender/IPA) rather than an LLM generation pass — strictly higher quality than
inventing one, and it's still "deterministic facts... not the LLM" in spirit. The LLM
generation path (`/v1/generate`) is left for quiz-item generation, a separate job.
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

from batch.config import CEFR_RANK_BANDS, OUTPUT_DIR
from batch.frequency import load_top_words
from batch.wiktextract import stream_matching_entries


def cefr_for_rank(rank: int) -> str:
    for max_rank, cefr in CEFR_RANK_BANDS:
        if rank <= max_rank:
            return cefr
    return "C1"


def word_id(lang: str, word: str) -> str:
    return hashlib.sha256(f"{lang}:{word}".encode()).hexdigest()[:32]


def sql_quote(value: str | None) -> str:
    if value is None:
        return "NULL"
    return "'" + value.replace("'", "''") + "'"


def build_rows(lang: str, top_n: int) -> list[dict]:
    freq = load_top_words(lang, top_n)
    target_words = {word.lower() for word, _rank in freq}
    print(f"[{lang}] {len(target_words)} target words from frequency list", file=sys.stderr)

    entries = stream_matching_entries(lang, target_words)
    print(f"[{lang}] matched {len(entries)}/{len(target_words)} words in Wiktionary", file=sys.stderr)

    rows = []
    for word, rank in freq:
        entry = entries.get(word.lower())
        if entry is None:
            continue
        rows.append(
            {
                "id": word_id(lang, entry.word),
                "lang": lang,
                "word": entry.word,
                "translation": entry.translation,
                "pos": entry.pos,
                "gender": entry.gender,
                "ipa": entry.ipa,
                "cefr": cefr_for_rank(rank),
                "topics_json": "[]",
                "frequency_rank": rank,
                "example": entry.example,
                "example_translation": entry.example_translation,
                "source": "pipeline",
                "verified": 1,  # gender/POS/IPA sourced directly from Wiktionary, not LLM-invented
            }
        )
    return rows


def rows_to_sql(rows: list[dict]) -> str:
    statements = []
    for r in rows:
        statements.append(
            "INSERT INTO content_words "
            "(id, lang, word, translation, pos, gender, ipa, cefr, topics_json, "
            "frequency_rank, example, example_translation, audio_key, source, verified) "
            "VALUES ("
            f"{sql_quote(r['id'])}, {sql_quote(r['lang'])}, {sql_quote(r['word'])}, "
            f"{sql_quote(r['translation'])}, {sql_quote(r['pos'])}, {sql_quote(r['gender'])}, "
            f"{sql_quote(r['ipa'])}, {sql_quote(r['cefr'])}, {sql_quote(r['topics_json'])}, "
            f"{r['frequency_rank']}, {sql_quote(r['example'])}, {sql_quote(r['example_translation'])}, "
            f"NULL, {sql_quote(r['source'])}, {r['verified']}"
            ") ON CONFLICT(lang, word) DO UPDATE SET "
            "translation=excluded.translation, pos=excluded.pos, gender=excluded.gender, "
            "ipa=excluded.ipa, cefr=excluded.cefr, frequency_rank=excluded.frequency_rank, "
            "example=excluded.example, example_translation=excluded.example_translation, "
            "verified=excluded.verified;"
        )
    return "\n".join(statements) + "\n"


def run(lang: str, top_n: int, dry_run: bool) -> None:
    rows = build_rows(lang, top_n)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sql_path = OUTPUT_DIR / f"seed_words_{lang}.sql"
    jsonl_path = OUTPUT_DIR / f"seed_words_{lang}.jsonl"

    sql_path.write_text(rows_to_sql(rows), encoding="utf-8")
    with jsonl_path.open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    print(f"[{lang}] wrote {len(rows)} rows -> {sql_path}", file=sys.stderr)
    if dry_run:
        print(f"[{lang}] dry-run: not applying to any database. Sample rows:", file=sys.stderr)
        for r in rows[:5]:
            print(f"  {r['word']} ({r['gender'] or '-'}) [{r['cefr']}] = {r['translation'][:60]}", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", required=True, choices=["de", "en"])
    parser.add_argument("--top-n", type=int, default=3000)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    run(args.lang, args.top_n, args.dry_run)


if __name__ == "__main__":
    main()
