"""Streams a kaikki.org wiktextract JSONL dump and extracts entries for a
target word set (CLAUDE.md §3: gender/POS/IPA come from Wiktionary, never
LLM invention). Each dump is 1-3GB — streamed line by line, never buffered,
with a cheap regex pre-check before the (much more expensive) json.loads so
scanning the full dump for a few thousand target words stays fast.
"""

import json
import re
from dataclasses import dataclass, field

import httpx

from batch.config import KAIKKI_DUMP_URL, LANG_NAMES

_WORD_FIELD_RE = re.compile(r'"word":\s*"((?:[^"\\]|\\.)*)"')

_GENDER_TAG_TO_ARTICLE = {
    "masculine": "der",
    "feminine": "die",
    "neuter": "das",
}

# Closed-class words (pronouns, articles, prepositions...) rank first: when a
# word has both a common closed-class sense and a rarer noun/verb homograph
# (e.g. "Ich" the pronoun "I" vs "das Ich" the noun "ego"), the closed-class
# sense is overwhelmingly the one a learner means — being usable as a
# preposition/pronoun/etc. at all is rarely coincidental. Open-class words
# (noun/verb/adj/adv/...) all tie at the same rank instead of an arbitrary
# sub-order: unlike German (where preferring verb senses generally helped),
# English has tons of noun/verb/adj homographs ("sick" the adjective vs. "to
# sick" the rare verb "to vomit") where no fixed part-of-speech order is
# right — richness/redirect-status (see WordEntry) decides among them.
_CLOSED_CLASS_PRIORITY = ["article", "pron", "det", "prep", "postp", "conj", "particle"]
_OPEN_CLASS_POS_LIST = ["verb", "adj", "adv", "noun", "name", "num", "intj", "phrase"]
_POS_PRIORITY = _CLOSED_CLASS_PRIORITY + _OPEN_CLASS_POS_LIST
# Kinship terms used as direct-address forms ("Mutter, komm her!") get
# classified as `name` by Wiktionary, not `noun` — grammatically they're
# ordinary common nouns, so store them as such.
_POS_STORAGE_ALIAS = {"name": "noun"}
_OPEN_CLASS_RANK = len(_CLOSED_CLASS_PRIORITY)  # every open-class pos ties here
_POS_RANK = {pos: i for i, pos in enumerate(_CLOSED_CLASS_PRIORITY)}
_POS_RANK.update({pos: _OPEN_CLASS_RANK for pos in _OPEN_CLASS_POS_LIST})

# Manual disambiguation for high-frequency homographs where Wiktionary's sense
# richness heuristic picks a technically-real but pedagogically-wrong sense
# (e.g. "Mutter" = mother, overwhelmingly, but "nut (for a bolt)" happened to
# have a richer entry). Still real Wiktionary data — this only *selects among*
# the candidates already extracted, never invents a translation. Extend this
# as more get spotted; there's no general fix for "which sense is common"
# without either frequency data Wiktionary doesn't expose or an LLM pass.
_KNOWN_TRANSLATION_HINTS: dict[tuple[str, str], str] = {
    ("de", "mutter"): "mother",
}

# For words where this specific Wiktionary extraction has *no* candidate with
# the right sense at all (e.g. "hallo" only has the noun "hullabaloo" sense
# extracted, no separate interjection entry) — a direct, manually-verified
# override. Keeps the real entry's pos/gender/ipa/example, only replaces the
# wrong gloss.
_KNOWN_TRANSLATION_OVERRIDES: dict[tuple[str, str], str] = {
    ("de", "hallo"): "hello, hi",
}


def _apply_known_hint(lang: str, word_lower: str, entries: list["WordEntry"]) -> "WordEntry | None":
    hint = _KNOWN_TRANSLATION_HINTS.get((lang, word_lower))
    if not hint:
        return None
    for entry in entries:
        if hint in entry.translation.lower():
            return entry
    return None


@dataclass
class WordEntry:
    word: str
    pos: str
    gender: str | None = None
    ipa: str | None = None
    translation: str = ""
    example: str | None = None
    example_translation: str | None = None
    topics: list[str] = field(default_factory=list)
    # Same-POS homographs (e.g. "Mutter" = mother vs. nut, both `noun`/`die`)
    # can't be disambiguated by POS alone — richer entries (more senses, an
    # audio recording) are a reasonable proxy for "the common meaning", since
    # Wiktionary contributors tend to flesh those out more than obscure senses.
    richness: int = 0
    # "Alternative letter-case form of X" / "alternative spelling of X" entries
    # are pointer stubs, not real definitions — never let one outrank a real
    # entry just because it happens to have more senses listed.
    is_redirect: bool = False


def _first_ipa(sounds: list[dict]) -> str | None:
    for s in sounds or []:
        if ipa := s.get("ipa"):
            return ipa
    return None


def _first_gender(senses: list[dict]) -> str | None:
    for sense in senses or []:
        for tag in sense.get("tags", []):
            if article := _GENDER_TAG_TO_ARTICLE.get(tag):
                return article
    return None


# German's heavy inflection means the OpenSubtitles frequency list is full of
# conjugated/declined forms ("gab", "schafft", "diesem", "roten"...) whose
# Wiktionary gloss is a grammatical description ("strong genitive
# masculine/neuter singular", "first/third-person singular preterite of
# geben"), not a translation — useless and confusing on a flashcard. Matching
# on the gloss's *first word* against a keyword set is far more robust here
# than trying to enumerate every multi-word phrasing Wiktionary uses.
# Skipping these falls back to a real dictionary-form candidate if one exists
# for the same word, or drops the word entirely if it doesn't.
_GRAMMATICAL_LEAD_WORDS = {
    "inflection", "gerund", "past", "present", "future", "preterite", "plural",
    "singular", "genitive", "dative", "accusative", "nominative", "masculine",
    "feminine", "neuter", "comparative", "superlative", "strong", "weak",
    "mixed", "imperative", "abbreviation",
    "first-person", "second-person", "third-person",
}
# Pointer/redirect stubs ("alternative form of X") are never useful content,
# regardless of POS — unlike the grammatical descriptions above, which are
# sometimes the only real content closed-class words have.
_REDIRECT_LEAD_WORDS = {"alternative"}

_OPEN_CLASS_POS = {"verb", "adj", "noun", "name"}


def _leading_tokens(gloss: str) -> list[str]:
    # "nominative/accusative/genitive plural of Ding" -> ["nominative", "accusative", ...]
    first_chunk = gloss.split(" ", 1)[0].strip(",:;").lower()
    return first_chunk.split("/")


def _is_grammatical_description(gloss: str) -> bool:
    return any(tok in _GRAMMATICAL_LEAD_WORDS for tok in _leading_tokens(gloss))


def _is_redirect(gloss: str) -> bool:
    # Checks the first few words, not just the first token — "Honorific
    # alternative letter-case form of you" needs word #2, not #1.
    leading_words = gloss.lower().replace(",", " ").split()[:4]
    return any(word in _REDIRECT_LEAD_WORDS for word in leading_words)


def _first_gloss(senses: list[dict], pos: str) -> str:
    # Only skip inflection-description glosses for open-class words (verb/adj/
    # noun) — for closed-class words (articles, pronouns...) that description
    # ("neuter singular of der: the") is often the only real content Wiktionary
    # has, and it's genuinely useful there ("das" = the neuter form of "the").
    skip_inflections = pos in _OPEN_CLASS_POS
    for sense in senses or []:
        for gloss in sense.get("glosses", []):
            cleaned = gloss.split(";")[0].strip()
            if not cleaned or _is_redirect(cleaned):
                continue
            if skip_inflections and _is_grammatical_description(cleaned):
                continue
            return cleaned[:200]
    return ""


def _first_example(senses: list[dict]) -> tuple[str | None, str | None]:
    for sense in senses or []:
        for ex in sense.get("examples", []):
            text = ex.get("text")
            translation = ex.get("translation") or ex.get("english")
            if text:
                return text, translation
    return None, None


def stream_matching_entries(lang: str, target_words: set[str]) -> dict[str, WordEntry]:
    """target_words must be lowercased. A word often has multiple POS entries
    (homographs); we keep every candidate seen and pick the best by
    _POS_PRIORITY once the stream ends, rather than just taking whichever
    happens to appear first in the file."""
    lang_name = LANG_NAMES[lang]
    url = KAIKKI_DUMP_URL.format(lang_name=lang_name)
    candidates: dict[str, list[WordEntry]] = {}

    with httpx.stream("GET", url, timeout=60.0, follow_redirects=True) as response:
        response.raise_for_status()
        for line in response.iter_lines():
            if not line:
                continue
            match = _WORD_FIELD_RE.search(line)
            if not match:
                continue
            word_lower = match.group(1).lower()
            if word_lower not in target_words:
                continue

            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue

            if data.get("lang_code") != lang:
                continue
            pos = data.get("pos", "")
            if pos not in _POS_RANK:
                continue
            storage_pos = _POS_STORAGE_ALIAS.get(pos, pos)

            senses = data.get("senses", [])
            translation = _first_gloss(senses, storage_pos)
            if not translation:  # skip entries with no usable gloss at all
                continue
            example, example_translation = _first_example(senses)
            sounds = data.get("sounds", [])
            has_audio = any("audio" in s for s in sounds)
            entry = WordEntry(
                word=data.get("word", word_lower),
                pos=storage_pos,
                gender=_first_gender(senses) if storage_pos == "noun" else None,
                ipa=_first_ipa(sounds),
                translation=translation,
                example=example,
                example_translation=example_translation,
                richness=len(senses) + (2 if has_audio else 0) + (1 if example else 0),
                is_redirect=translation.lower().startswith(("alternative ", "obsolete ", "archaic ", "dated ")),
            )
            candidates.setdefault(word_lower, []).append(entry)

    result = {}
    for word, entries in candidates.items():
        best = _apply_known_hint(lang, word, entries) or min(
            entries, key=lambda e: (_POS_RANK[e.pos], e.is_redirect, -e.richness)
        )
        if override := _KNOWN_TRANSLATION_OVERRIDES.get((lang, word)):
            best.translation = override
        result[word] = best
    return result
