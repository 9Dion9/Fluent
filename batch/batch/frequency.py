"""Hermit Dave / OpenSubtitles frequency lists (CLAUDE.md §3)."""

import httpx

from batch.config import CACHE_DIR, FREQUENCY_LIST_URL, TOP_N_WORDS


def load_top_words(lang: str, top_n: int = TOP_N_WORDS) -> list[tuple[str, int]]:
    """Returns [(word, rank)] for the top_n most frequent words, rank starting at 1.
    Cached to disk — this file barely changes, no need to re-fetch every run."""
    cache_path = CACHE_DIR / f"freq_{lang}.txt"
    if cache_path.exists():
        text = cache_path.read_text(encoding="utf-8")
    else:
        url = FREQUENCY_LIST_URL.format(lang=lang)
        res = httpx.get(url, timeout=30.0, follow_redirects=True)
        res.raise_for_status()
        text = res.text
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(text, encoding="utf-8")

    words: list[tuple[str, int]] = []
    for line in text.splitlines():
        parts = line.strip().split()
        if not parts:
            continue
        word = parts[0]
        # Frequency lists include punctuation/single letters/numerals we don't want as vocab.
        if not word.isalpha():
            continue
        words.append((word, len(words) + 1))
        if len(words) >= top_n:
            break
    return words
