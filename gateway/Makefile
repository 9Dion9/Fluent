.PHONY: dev test eval

dev:
	.venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

test:
	.venv/bin/pytest -q

eval:
	.venv/bin/python -m tests.eval_tutor
