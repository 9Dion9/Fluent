#!/usr/bin/env bash
# Applies /infra/migrations to the fluent-db D1 database.
# Usage: ./migrate.sh [--local | --remote]   (default: --local)
set -euo pipefail
cd "$(dirname "$0")"

TARGET="${1:---local}"
npx wrangler d1 migrations apply fluent-db --config wrangler.toml "$TARGET"
