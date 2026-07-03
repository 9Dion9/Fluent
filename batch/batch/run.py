"""Batch job dispatcher. Usage: python -m batch.run <job> --lang de [--dry-run]"""

import argparse
import sys

JOBS = {
    "seed_words": "batch.seed_words",
}


def main() -> None:
    parser = argparse.ArgumentParser(prog="batch.run")
    parser.add_argument("job", choices=sorted(JOBS.keys()))
    args, remaining = parser.parse_known_args()

    if args.job == "seed_words":
        from batch import seed_words

        sys.argv = [sys.argv[0], *remaining]
        seed_words.main()


if __name__ == "__main__":
    main()
