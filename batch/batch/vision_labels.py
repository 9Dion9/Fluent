"""Batch job: builds vision_labels (CLAUDE.md §9, M7) — maps common Vision
classifier labels to Wiktionary-verified content_words. Curated, not
exhaustive: Apple's on-device classifier vocabulary isn't public, so this
covers ~65 common household/office objects likely to appear in early manual
testing. Documented limitation, not a bug — the Gemma VLM fallback
(worker POST /v1/vision/identify) covers everything this list misses, and a
correct fallback identification self-caches into vision_labels for next time
(see worker/src/repos/vision.ts upsertVisionLabelMapping) so the mapping
grows organically from real usage.

Deliberate deviation from the seed_words.py pattern: the per-language target
word here is *chosen* by this file (a translation judgment call, e.g.
"cup" -> "Tasse"), not derived from a frequency list — there's no bilingual
dictionary source in the pipeline to automate that mapping. Gender/POS/IPA
for the chosen word still come straight from Wiktionary, never invented.
"""

import hashlib
import json
import sys

from batch.config import OUTPUT_DIR
from batch.wiktextract import stream_matching_entries

CEFR_DEFAULT = "A1"  # household objects skew introductory

# Each entry: Vision-classifier-style labels (lowercase, as the app will send
# them) -> the canonical target word to look up in Wiktionary per language.
VISION_OBJECTS: list[dict] = [
    {"labels": ["cup", "coffee cup", "mug"], "de": "Tasse", "en": "cup"},
    {"labels": ["chair"], "de": "Stuhl", "en": "chair"},
    {"labels": ["table", "desk"], "de": "Tisch", "en": "table"},
    {"labels": ["book"], "de": "Buch", "en": "book"},
    {"labels": ["key", "keys"], "de": "Schlüssel", "en": "key"},
    {"labels": ["telephone", "cellular telephone", "phone", "smartphone"], "de": "Telefon", "en": "phone"},
    {"labels": ["bottle", "water bottle"], "de": "Flasche", "en": "bottle"},
    {"labels": ["plate"], "de": "Teller", "en": "plate"},
    {"labels": ["spoon"], "de": "Löffel", "en": "spoon"},
    {"labels": ["fork"], "de": "Gabel", "en": "fork"},
    {"labels": ["knife"], "de": "Messer", "en": "knife"},
    {"labels": ["bag", "handbag"], "de": "Tasche", "en": "bag"},
    {"labels": ["shoe"], "de": "Schuh", "en": "shoe"},
    {"labels": ["clock", "wall clock"], "de": "Uhr", "en": "clock"},
    {"labels": ["lamp", "table lamp"], "de": "Lampe", "en": "lamp"},
    {"labels": ["window"], "de": "Fenster", "en": "window"},
    {"labels": ["door"], "de": "Tür", "en": "door"},
    {"labels": ["mirror"], "de": "Spiegel", "en": "mirror"},
    {"labels": ["pillow"], "de": "Kissen", "en": "pillow"},
    {"labels": ["blanket"], "de": "Decke", "en": "blanket"},
    {"labels": ["towel"], "de": "Handtuch", "en": "towel"},
    {"labels": ["soap", "bar of soap"], "de": "Seife", "en": "soap"},
    {"labels": ["umbrella"], "de": "Regenschirm", "en": "umbrella"},
    {"labels": ["glasses", "eyeglasses", "sunglasses"], "de": "Brille", "en": "glasses"},
    {"labels": ["watch", "wristwatch"], "de": "Armbanduhr", "en": "watch"},
    {"labels": ["wallet"], "de": "Brieftasche", "en": "wallet"},
    {"labels": ["backpack"], "de": "Rucksack", "en": "backpack"},
    {"labels": ["laptop", "laptop computer", "notebook computer"], "de": "Laptop", "en": "laptop"},
    {"labels": ["computer", "desktop computer"], "de": "Computer", "en": "computer"},
    {"labels": ["keyboard", "computer keyboard"], "de": "Tastatur", "en": "keyboard"},
    {"labels": ["mouse", "computer mouse"], "de": "Maus", "en": "mouse"},
    {"labels": ["monitor", "computer monitor", "screen"], "de": "Bildschirm", "en": "monitor"},
    {"labels": ["headphones", "headphone"], "de": "Kopfhörer", "en": "headphones"},
    {"labels": ["television", "tv", "television set"], "de": "Fernseher", "en": "television"},
    {"labels": ["sofa", "couch"], "de": "Sofa", "en": "sofa"},
    {"labels": ["bed"], "de": "Bett", "en": "bed"},
    {"labels": ["refrigerator", "fridge"], "de": "Kühlschrank", "en": "refrigerator"},
    {"labels": ["microwave", "microwave oven"], "de": "Mikrowelle", "en": "microwave"},
    {"labels": ["sink"], "de": "Spüle", "en": "sink"},
    {"labels": ["candle"], "de": "Kerze", "en": "candle"},
    {"labels": ["box", "cardboard box"], "de": "Kiste", "en": "box"},
    {"labels": ["pen", "ballpoint pen"], "de": "Stift", "en": "pen"},
    {"labels": ["pencil"], "de": "Bleistift", "en": "pencil"},
    {"labels": ["scissors"], "de": "Schere", "en": "scissors"},
    {"labels": ["calculator"], "de": "Taschenrechner", "en": "calculator"},
    {"labels": ["remote control", "remote"], "de": "Fernbedienung", "en": "remote control"},
    {"labels": ["speaker", "loudspeaker"], "de": "Lautsprecher", "en": "speaker"},
    {"labels": ["camera"], "de": "Kamera", "en": "camera"},
    {"labels": ["guitar"], "de": "Gitarre", "en": "guitar"},
    {"labels": ["plant", "houseplant", "flowerpot"], "de": "Pflanze", "en": "plant"},
    {"labels": ["flower"], "de": "Blume", "en": "flower"},
    {"labels": ["tree"], "de": "Baum", "en": "tree"},
    {"labels": ["apple"], "de": "Apfel", "en": "apple"},
    {"labels": ["banana"], "de": "Banane", "en": "banana"},
    {"labels": ["bread", "loaf of bread"], "de": "Brot", "en": "bread"},
    {"labels": ["cheese"], "de": "Käse", "en": "cheese"},
    {"labels": ["cat"], "de": "Katze", "en": "cat"},
    {"labels": ["dog"], "de": "Hund", "en": "dog"},
    {"labels": ["car", "automobile"], "de": "Auto", "en": "car"},
    {"labels": ["bicycle", "bike"], "de": "Fahrrad", "en": "bicycle"},
    {"labels": ["hat"], "de": "Hut", "en": "hat"},
    {"labels": ["glove"], "de": "Handschuh", "en": "glove"},
    {"labels": ["scarf"], "de": "Schal", "en": "scarf"},
    {"labels": ["jacket"], "de": "Jacke", "en": "jacket"},
    {"labels": ["belt"], "de": "Gürtel", "en": "belt"},
    {"labels": ["sock"], "de": "Socke", "en": "sock"},
    {"labels": ["broom"], "de": "Besen", "en": "broom"},
    {"labels": ["bucket", "pail"], "de": "Eimer", "en": "bucket"},
    {"labels": ["vase"], "de": "Vase", "en": "vase"},
    {"labels": ["bowl"], "de": "Schüssel", "en": "bowl"},
    {"labels": ["basket"], "de": "Korb", "en": "basket"},
]


def word_id(lang: str, word: str) -> str:
    return hashlib.sha256(f"{lang}:{word}".encode()).hexdigest()[:32]


def sql_quote(value) -> str:
    return "NULL" if value is None else "'" + str(value).replace("'", "''") + "'"


def build(lang: str) -> tuple[list[dict], list[dict]]:
    """Returns (content_word_rows, vision_label_rows)."""
    target_words = {obj[lang].lower() for obj in VISION_OBJECTS}
    entries = stream_matching_entries(lang, target_words)
    print(f"[{lang}] matched {len(entries)}/{len(target_words)} vision-object words in Wiktionary", file=sys.stderr)

    word_rows = []
    label_rows = []
    missing = []
    for obj in VISION_OBJECTS:
        target = obj[lang]
        entry = entries.get(target.lower())
        if entry is None:
            missing.append(target)
            continue
        word_rows.append(
            {
                "id": word_id(lang, entry.word),
                "lang": lang,
                "word": entry.word,
                "translation": entry.translation,
                "pos": entry.pos,
                "gender": entry.gender,
                "ipa": entry.ipa,
                "example": entry.example,
                "example_translation": entry.example_translation,
            }
        )
        for label in obj["labels"]:
            label_rows.append({"label": label, "lang": lang, "word": entry.word})

    if missing:
        print(f"[{lang}] WARNING: not found in Wiktionary, skipped: {missing}", file=sys.stderr)
    return word_rows, label_rows


def rows_to_sql(word_rows: list[dict], label_rows: list[dict]) -> str:
    statements = []
    for r in word_rows:
        statements.append(
            "INSERT INTO content_words "
            "(id, lang, word, translation, pos, gender, ipa, cefr, topics_json, example, example_translation, source, verified) "
            f"VALUES ({sql_quote(r['id'])}, {sql_quote(r['lang'])}, {sql_quote(r['word'])}, {sql_quote(r['translation'])}, "
            f"{sql_quote(r['pos'])}, {sql_quote(r['gender'])}, {sql_quote(r['ipa'])}, {sql_quote(CEFR_DEFAULT)}, '[]', "
            f"{sql_quote(r['example'])}, {sql_quote(r['example_translation'])}, 'pipeline', 1) "
            "ON CONFLICT(lang, word) DO UPDATE SET translation=excluded.translation, pos=excluded.pos, "
            "gender=excluded.gender, ipa=excluded.ipa, verified=excluded.verified;"
        )
    for r in label_rows:
        # Looked up by (lang, word) rather than a computed id — the word may
        # already exist from M5 seeding under a different row id, and
        # ON CONFLICT above never changes an existing primary key.
        statements.append(
            "INSERT OR IGNORE INTO vision_labels (label, lang, word_id) "
            f"SELECT {sql_quote(r['label'])}, {sql_quote(r['lang'])}, id FROM content_words "
            f"WHERE lang={sql_quote(r['lang'])} AND word={sql_quote(r['word'])};"
        )
    return "\n".join(statements) + "\n"


def run(lang: str, dry_run: bool) -> None:
    word_rows, label_rows = build(lang)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sql_path = OUTPUT_DIR / f"vision_labels_{lang}.sql"
    jsonl_path = OUTPUT_DIR / f"vision_labels_{lang}.jsonl"

    sql_path.write_text(rows_to_sql(word_rows, label_rows), encoding="utf-8")
    with jsonl_path.open("w", encoding="utf-8") as f:
        for r in word_rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    print(f"[{lang}] wrote {len(word_rows)} words / {len(label_rows)} label mappings -> {sql_path}", file=sys.stderr)
    if dry_run:
        for r in word_rows[:5]:
            print(f"  {r['word']} ({r['gender'] or '-'}) = {r['translation'][:60]}", file=sys.stderr)


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", required=True, choices=["de", "en"])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    run(args.lang, args.dry_run)


if __name__ == "__main__":
    main()
