"""Quiz bank generation (CLAUDE.md §3, M6). Per shared/schemas/quiz.json:
  mcq:       prompt={question, options}         answer={correct_index}
  match:     prompt={left, right}  (right shuffled)  answer={correct_pairs: [[left_i, right_i], ...]}
  fillblank: prompt={sentence, blank_index}     answer={correct_word}
  order:     prompt={tokens}       (shuffled)   answer={correct_order: [...]}

match/fillblank/order are built deterministically from already Wiktionary-verified
words/examples — zero LLM cost, zero hallucination risk. Only mcq genuinely needs the
LLM (gpt-oss:20b, batch model per CLAUDE.md §3), for plausible wrong-answer distractors,
which isn't something the data itself provides.
"""

import argparse
import asyncio
import hashlib
import json
import random
import re
import sys
from pathlib import Path

import httpx

from batch.config import OUTPUT_DIR

GATEWAY_URL = "http://127.0.0.1:8000"
GATEWAY_SECRET_PATH = Path(__file__).resolve().parent.parent.parent / "infra" / ".dev.vars"


def _gateway_secret() -> str:
    for line in GATEWAY_SECRET_PATH.read_text().splitlines():
        if line.startswith("GATEWAY_SHARED_SECRET="):
            return line.split("=", 1)[1].strip()
    raise RuntimeError("GATEWAY_SHARED_SECRET not found in infra/.dev.vars")


CEFR_DIFFICULTY = {"A1": 1, "A2": 2, "B1": 3, "B2": 4, "C1": 5}


def word_id(lang: str, word: str) -> str:
    return hashlib.sha256(f"{lang}:{word}".encode()).hexdigest()[:32]


def quiz_id(lang: str, quiz_type: str, content_hash: str) -> str:
    return hashlib.sha256(f"{lang}:{quiz_type}:{content_hash}".encode()).hexdigest()[:32]


def load_words(lang: str) -> list[dict]:
    path = OUTPUT_DIR / f"seed_words_{lang}.jsonl"
    if not path.exists():
        raise SystemExit(f"{path} not found — run `python -m batch.run seed_words --lang {lang}` first.")
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]


# --- deterministic generators (no LLM) ---


def gen_match_quizzes(words: list[dict], lang: str, group_size: int = 4) -> list[dict]:
    usable = [w for w in words if w["translation"]]
    random.Random(42).shuffle(usable)
    rows = []
    for i in range(0, len(usable) - group_size + 1, group_size):
        group = usable[i : i + group_size]
        left = [w["word"] for w in group]
        right_order = list(range(group_size))
        random.Random(i).shuffle(right_order)
        right = [_short_translation(group[j]["translation"], 40) for j in right_order]
        correct_pairs = [[left_i, right_order.index(left_i)] for left_i in range(group_size)]
        content_hash = hashlib.sha256(",".join(w["id"] for w in group).encode()).hexdigest()
        rows.append(
            {
                "id": quiz_id(lang, "match", content_hash),
                "lang": lang,
                "type": "match",
                "prompt_json": json.dumps({"left": left, "right": right}, ensure_ascii=False),
                "answer_json": json.dumps({"correct_pairs": correct_pairs}),
                "difficulty": CEFR_DIFFICULTY.get(group[0]["cefr"], 1),
                "word_ids_json": json.dumps([w["id"] for w in group]),
                "content_hash": content_hash,
            }
        )
    return rows


def gen_fillblank_quizzes(words: list[dict], lang: str) -> list[dict]:
    by_pos: dict[str, list[dict]] = {}
    for w in words:
        by_pos.setdefault(w["pos"], []).append(w)

    rows = []
    for w in words:
        if not w["example"] or w["word"].lower() not in w["example"].lower():
            continue
        tokens = w["example"].split()
        blank_index = next(
            (i for i, t in enumerate(tokens) if w["word"].lower() in t.lower().strip(".,!?\"'")), None
        )
        if blank_index is None:
            continue

        content_hash = hashlib.sha256(f"fillblank:{w['id']}".encode()).hexdigest()
        rows.append(
            {
                "id": quiz_id(lang, "fillblank", content_hash),
                "lang": lang,
                "type": "fillblank",
                "prompt_json": json.dumps({"sentence": w["example"], "blank_index": blank_index}, ensure_ascii=False),
                "answer_json": json.dumps({"correct_word": w["word"]}, ensure_ascii=False),
                "difficulty": CEFR_DIFFICULTY.get(w["cefr"], 1),
                "word_ids_json": json.dumps([w["id"]]),
                "content_hash": content_hash,
            }
        )
    return rows


def gen_order_quizzes(words: list[dict], lang: str) -> list[dict]:
    rows = []
    for w in words:
        if not w["example"]:
            continue
        tokens = w["example"].split()
        if not (3 <= len(tokens) <= 8):
            continue

        shuffled_indices = list(range(len(tokens)))
        random.Random(w["id"]).shuffle(shuffled_indices)
        if shuffled_indices == list(range(len(tokens))):  # already-sorted shuffle is a useless quiz
            continue
        shuffled_tokens = [tokens[i] for i in shuffled_indices]
        # correct_order[i] = position in shuffled_tokens of the i-th original word
        correct_order = [shuffled_indices.index(i) for i in range(len(tokens))]

        content_hash = hashlib.sha256(f"order:{w['id']}".encode()).hexdigest()
        rows.append(
            {
                "id": quiz_id(lang, "order", content_hash),
                "lang": lang,
                "type": "order",
                "prompt_json": json.dumps({"tokens": shuffled_tokens}, ensure_ascii=False),
                "answer_json": json.dumps({"correct_order": correct_order}),
                "difficulty": CEFR_DIFFICULTY.get(w["cefr"], 1),
                "word_ids_json": json.dumps([w["id"]]),
                "content_hash": content_hash,
            }
        )
    return rows


# --- LLM-assisted generator (mcq only — needs plausible wrong-answer distractors) ---


async def _gateway_chat(messages: list[dict]) -> str:
    async with httpx.AsyncClient(timeout=60.0) as client:
        res = await client.post(
            f"{GATEWAY_URL}/v1/chat",
            headers={"X-Gateway-Secret": _gateway_secret()},
            json={"messages": messages, "model": "gpt-oss:20b", "keep_alive": 0},
        )
        res.raise_for_status()
        return res.json()["text"]


def _short_translation(translation: str, max_len: int = 60) -> str:
    """Truncates at a word boundary — a mid-word cut confuses the LLM into
    treating the fragment as the literal answer text."""
    if len(translation) <= max_len:
        return translation
    return translation[:max_len].rsplit(" ", 1)[0]


async def gen_mcq_quiz(w: dict, lang_name: str) -> dict | None:
    prompt = (
        f'Return ONLY valid JSON: {{"question": string, "options": string[4], "correct_index": number}} '
        f"— a {lang_name} {w['cefr']} multiple-choice vocabulary quiz asking what \"{w['word']}\" means. "
        f"The correct answer (at correct_index) must be: {_short_translation(w['translation'])}. "
        f"The other 3 options must be plausible but wrong {lang_name}-to-English vocab answers, not obviously silly."
    )
    try:
        raw = await _gateway_chat([{"role": "user", "content": prompt}])
        data = json.loads(raw)
        if not (
            isinstance(data.get("question"), str)
            and isinstance(data.get("options"), list)
            and len(data["options"]) == 4
            and isinstance(data.get("correct_index"), int)
            and 0 <= data["correct_index"] < 4
        ):
            return None
        # Semantic sanity check, not just shape: the model occasionally marks
        # the WRONG option as correct (e.g. "sein"="to be" but correct_index
        # pointed at "seiner", a distractor). Bag-of-words overlap between the
        # known-correct translation and the chosen option catches this cheaply
        # without a second model call.
        translation_words = set(re.findall(r"[a-z]+", w["translation"].lower()))
        chosen_words = set(re.findall(r"[a-z]+", data["options"][data["correct_index"]].lower()))
        if not translation_words & chosen_words:
            return None
    except (json.JSONDecodeError, httpx.HTTPError, KeyError):
        return None

    content_hash = hashlib.sha256(f"mcq:{w['id']}".encode()).hexdigest()
    return {
        "id": quiz_id(w["lang"], "mcq", content_hash),
        "lang": w["lang"],
        "type": "mcq",
        "prompt_json": json.dumps({"question": data["question"], "options": data["options"]}, ensure_ascii=False),
        "answer_json": json.dumps({"correct_index": data["correct_index"]}),
        "difficulty": CEFR_DIFFICULTY.get(w["cefr"], 1),
        "word_ids_json": json.dumps([w["id"]]),
        "content_hash": content_hash,
    }


async def gen_mcq_quizzes(words: list[dict], lang: str, n: int, lang_name: str) -> list[dict]:
    sample = [w for w in words if w["translation"]][:n]
    rows = []
    for i, w in enumerate(sample):
        row = await gen_mcq_quiz(w, lang_name)
        if row:
            rows.append(row)
        print(f"  mcq {i + 1}/{len(sample)}", file=sys.stderr, end="\r")
    print(file=sys.stderr)
    return rows


def rows_to_sql(rows: list[dict]) -> str:
    def q(v):
        return "NULL" if v is None else "'" + str(v).replace("'", "''") + "'"

    statements = []
    for r in rows:
        statements.append(
            "INSERT INTO quizzes (id, lang, type, prompt_json, answer_json, difficulty, word_ids_json, content_hash) "
            f"VALUES ({q(r['id'])}, {q(r['lang'])}, {q(r['type'])}, {q(r['prompt_json'])}, {q(r['answer_json'])}, "
            f"{r['difficulty']}, {q(r['word_ids_json'])}, {q(r['content_hash'])}) "
            "ON CONFLICT(content_hash) DO UPDATE SET prompt_json=excluded.prompt_json, "
            "answer_json=excluded.answer_json, difficulty=excluded.difficulty;"
        )
    return "\n".join(statements) + "\n"


async def run(lang: str, mcq_count: int, dry_run: bool) -> None:
    from batch.config import LANG_NAMES

    words = load_words(lang)
    all_rows = []
    all_rows += gen_match_quizzes(words, lang)
    all_rows += gen_fillblank_quizzes(words, lang)
    all_rows += gen_order_quizzes(words, lang)
    print(
        f"[{lang}] deterministic: {len(all_rows)} quizzes (match/fillblank/order)",
        file=sys.stderr,
    )

    if mcq_count > 0:
        mcq_rows = await gen_mcq_quizzes(words, lang, mcq_count, LANG_NAMES[lang])
        print(f"[{lang}] mcq: {len(mcq_rows)}/{mcq_count} generated", file=sys.stderr)
        all_rows += mcq_rows

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sql_path = OUTPUT_DIR / f"quizzes_{lang}.sql"
    sql_path.write_text(rows_to_sql(all_rows), encoding="utf-8")
    print(f"[{lang}] wrote {len(all_rows)} quizzes -> {sql_path}", file=sys.stderr)

    if dry_run:
        by_type = {}
        for r in all_rows:
            by_type[r["type"]] = by_type.get(r["type"], 0) + 1
        print(f"[{lang}] by type: {by_type}", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", required=True, choices=["de", "en"])
    parser.add_argument("--mcq-count", type=int, default=100)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    asyncio.run(run(args.lang, args.mcq_count, args.dry_run))


if __name__ == "__main__":
    main()
