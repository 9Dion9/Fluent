#!/usr/bin/env bash
# Nightly D1 export backup (CLAUDE.md §14): dumps the production DB, keeps the
# 14 most recent dumps, deletes older ones. R2 audio is reproducible from the
# batch pipeline (batch/README.md) so it isn't backed up here — only D1.
#
# Requires CLOUDFLARE_API_TOKEN in the environment. Cron should export it from
# a gitignored token file, never inline in the crontab itself:
#   CLOUDFLARE_API_TOKEN=$(cat /path/to/token/file) /path/to/infra/backup.sh
set -euo pipefail
cd "$(dirname "$0")"

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "CLOUDFLARE_API_TOKEN is not set — aborting backup." >&2
  exit 1
fi

BACKUP_DIR="$(dirname "$0")/backups"
mkdir -p "$BACKUP_DIR"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT="$BACKUP_DIR/fluent-db-$TIMESTAMP.sql"

npx wrangler d1 export fluent-db --config wrangler.toml --remote --output "$OUTPUT"

# Rotate: keep only the 14 most recent dumps (CLAUDE.md §14: "keeps 14 rotated dumps").
ls -1t "$BACKUP_DIR"/fluent-db-*.sql 2>/dev/null | tail -n +15 | xargs -r rm --

echo "Backup written to $OUTPUT"
