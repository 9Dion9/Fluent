from pathlib import Path

BATCH_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = BATCH_ROOT / "output"
CACHE_DIR = BATCH_ROOT / ".cache"

# CLAUDE.md §3: "Seed content_words from frequency lists (Hermit Dave / OpenSubtitles)
# + wiktextract dumps (kaikki.org) for gender, POS, and IPA."
FREQUENCY_LIST_URL = "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/{lang}/{lang}_50k.txt"
KAIKKI_DUMP_URL = "https://kaikki.org/dictionary/{lang_name}/kaikki.org-dictionary-{lang_name}.jsonl"

# Only these two target languages exist in v1 (CLAUDE.md §0).
LANG_NAMES = {
    "de": "German",
    "en": "English",
}

# CEFR-ish default: top N words by frequency rank drives a rough level cutoff,
# refined later once real usage data exists. Word #1-500 -> A1 ... #2500+ -> B1.
CEFR_RANK_BANDS = [
    (500, "A1"),
    (1500, "A2"),
    (2500, "B1"),
    (4000, "B2"),
    (999_999, "C1"),
]

TOP_N_WORDS = 3000
