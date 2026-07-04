"""Scenario catalog seed job (CLAUDE.md §3/§7, "scenario picker" — DESIGN.md
§8). Hand-authored, not extracted from any open-data source (unlike
seed_words/vision_labels) — a roleplay premise is inherently written content,
there's no deterministic source for "what should a coffee-shop scenario say."
`seed_prompt` is in English regardless of target language: it's an
instruction to the model (injected as {SCENARIO} in prompt.py's system
prompt template), not user-facing content.

focus_word_ids are looked up best-effort against that language's already-run
seed_words output (batch/output/seed_words_{lang}.jsonl) — a scenario still
seeds fine with fewer/no focus words if a chosen word isn't in that list.
"""

import hashlib
import json
import sys

from batch.config import OUTPUT_DIR

# (title, emoji, min_level, seed_prompt, [focus words in the TARGET language])
SCENARIOS: list[tuple[str, str, str, str, list[str]]] = [
    (
        "Order a coffee",
        "☕",
        "A1",
        "You are a friendly barista at a cafe. Greet the learner, help them order a "
        "coffee or tea, and naturally work in words for drink sizes, milk, and sugar.",
        ["Kaffee", "Tasse", "Milch", "Zucker"],
    ),
    (
        "At the supermarket",
        "🛒",
        "A1",
        "You are a helpful shop assistant. Help the learner find and ask about "
        "everyday groceries (bread, milk, fruit) and understand prices.",
        ["Brot", "Milch", "Apfel", "Tasche"],
    ),
    (
        "Check in at a hotel",
        "🏨",
        "A2",
        "You are a hotel receptionist. Check the learner in, confirm their "
        "reservation, hand over the room key, and mention breakfast times.",
        ["Zimmer", "Schlüssel", "Nacht", "Frühstück"],
    ),
    (
        "At a party",
        "🎉",
        "A2",
        "You are a warm, chatty host at a party. Introduce yourself, offer the "
        "learner a drink, and make small talk about music and mutual friends.",
        ["Party", "Getränk", "Musik", "Freund"],
    ),
    (
        "Asking for directions",
        "🚉",
        "A2",
        "You are a local the learner has stopped on the street. Help them find the "
        "train station, using simple directions (left, right, straight ahead).",
        ["Straße", "Bahnhof", "links", "rechts"],
    ),
    (
        "At a restaurant",
        "🍽️",
        "A2",
        "You are a waiter at a restaurant. Present the menu, take the learner's "
        "order, check on food/drink preferences, and bring the bill when asked.",
        ["Speisekarte", "Wasser", "Rechnung", "Tisch"],
    ),
    (
        "At the doctor",
        "🩺",
        "B1",
        "You are a calm, reassuring doctor. Ask the learner what's wrong, discuss "
        "symptoms, and suggest simple next steps or medicine.",
        ["Arzt", "Schmerz", "Medikament", "Termin"],
    ),
    (
        "Job interview",
        "💼",
        "B1",
        "You are a friendly interviewer at a company. Ask the learner about their "
        "experience and skills, and answer questions they have about the role.",
        ["Arbeit", "Erfahrung", "Vorstellungsgespräch", "Lebenslauf"],
    ),
]

# English-target learners get the same premises but with English focus words
# (content_words.translation is always an English gloss, so "focus word" for
# an English-target learner is just the English word itself).
_EN_FOCUS_WORDS = {
    "Order a coffee": ["coffee", "cup", "milk", "sugar"],
    "At the supermarket": ["bread", "milk", "apple", "bag"],
    "Check in at a hotel": ["room", "key", "night", "breakfast"],
    "At a party": ["party", "drink", "music", "friend"],
    "Asking for directions": ["street", "station", "left", "right"],
    "At a restaurant": ["menu", "water", "bill", "table"],
    "At the doctor": ["doctor", "pain", "medicine", "appointment"],
    "Job interview": ["work", "experience", "interview", "resume"],
}


def scenario_id(lang: str, title: str) -> str:
    return hashlib.sha256(f"{lang}:{title}".encode()).hexdigest()[:32]


def word_id(lang: str, word: str) -> str:
    return hashlib.sha256(f"{lang}:{word}".encode()).hexdigest()[:32]


def load_word_ids_by_word(lang: str) -> dict[str, str]:
    path = OUTPUT_DIR / f"seed_words_{lang}.jsonl"
    if not path.exists():
        print(f"[{lang}] WARNING: {path} not found — scenarios will seed with no focus words", file=sys.stderr)
        return {}
    words = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]
    return {w["word"]: w["id"] for w in words}


def build_rows(lang: str) -> list[dict]:
    known_ids = load_word_ids_by_word(lang)
    rows = []
    for title, emoji, min_level, seed_prompt, de_words in SCENARIOS:
        target_words = de_words if lang == "de" else _EN_FOCUS_WORDS[title]
        focus_ids = [known_ids[w] for w in target_words if w in known_ids]
        missing = [w for w in target_words if w not in known_ids]
        if missing:
            print(f"[{lang}] '{title}': no seeded word for {missing} — omitted from focus_word_ids", file=sys.stderr)

        rows.append(
            {
                "id": scenario_id(lang, title),
                "lang": lang,
                "title": title,
                "emoji": emoji,
                "min_level": min_level,
                "seed_prompt": seed_prompt,
                "focus_word_ids_json": json.dumps(focus_ids),
            }
        )
    return rows


def sql_quote(value) -> str:
    return "NULL" if value is None else "'" + str(value).replace("'", "''") + "'"


def rows_to_sql(rows: list[dict]) -> str:
    statements = []
    for r in rows:
        statements.append(
            "INSERT INTO scenarios (id, lang, title, emoji, min_level, seed_prompt, focus_word_ids_json) "
            f"VALUES ({sql_quote(r['id'])}, {sql_quote(r['lang'])}, {sql_quote(r['title'])}, {sql_quote(r['emoji'])}, "
            f"{sql_quote(r['min_level'])}, {sql_quote(r['seed_prompt'])}, {sql_quote(r['focus_word_ids_json'])}) "
            "ON CONFLICT(id) DO UPDATE SET title=excluded.title, emoji=excluded.emoji, "
            "min_level=excluded.min_level, seed_prompt=excluded.seed_prompt, "
            "focus_word_ids_json=excluded.focus_word_ids_json;"
        )
    return "\n".join(statements) + "\n"


def run(lang: str, dry_run: bool) -> None:
    rows = build_rows(lang)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sql_path = OUTPUT_DIR / f"scenarios_{lang}.sql"
    sql_path.write_text(rows_to_sql(rows), encoding="utf-8")
    print(f"[{lang}] wrote {len(rows)} scenarios -> {sql_path}", file=sys.stderr)

    if dry_run:
        for r in rows:
            print(f"  {r['emoji']} {r['title']} [{r['min_level']}]", file=sys.stderr)


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", required=True, choices=["de", "en"])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    run(args.lang, args.dry_run)


if __name__ == "__main__":
    main()
