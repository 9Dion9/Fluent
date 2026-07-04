"""Batch job dispatcher. Usage: python -m batch.run <job> --lang de [--dry-run]"""

import argparse
import sys

JOBS = {
    "seed_words": "batch.seed_words",
    "quiz_gen": "batch.quiz_gen",
    "vision_labels": "batch.vision_labels",
    "report": "batch.report",
    "scenarios": "batch.scenarios",
}


def main() -> None:
    parser = argparse.ArgumentParser(prog="batch.run")
    parser.add_argument("job", choices=sorted(JOBS.keys()))
    args, remaining = parser.parse_known_args()

    sys.argv = [sys.argv[0], *remaining]
    if args.job == "seed_words":
        from batch import seed_words

        seed_words.main()
    elif args.job == "quiz_gen":
        from batch import quiz_gen

        quiz_gen.main()
    elif args.job == "vision_labels":
        from batch import vision_labels

        vision_labels.main()
    elif args.job == "report":
        from batch import report

        report.main()
    elif args.job == "scenarios":
        from batch import scenarios

        scenarios.main()


if __name__ == "__main__":
    main()
