#!/usr/bin/env bash
# Health probe + ntfy.sh alert (CLAUDE.md §14): "1-minute gateway health probe
# that pushes an alert via ntfy.sh (free) after 3 consecutive failures. Same
# for Worker /v1/health (catches tunnel breakage)."
#
# Meant to run every minute via cron. State (consecutive-failure counts) is
# kept in small files next to this script so a fresh process each run doesn't
# lose count. Sends one alert on the 3rd consecutive failure (not every
# minute after — that would defeat the point of an alert), and one
# "recovered" notice when a previously-failing target comes back.
#
# Configure via environment (a systemd unit / cron wrapper should set these):
#   NTFY_TOPIC          required — your private ntfy.sh topic name
#   GATEWAY_HEALTH_URL   default: http://127.0.0.1:8000/healthz
#   WORKER_HEALTH_URL    default: https://fluent-worker.dionmain.workers.dev/v1/health
set -euo pipefail
cd "$(dirname "$0")"

NTFY_TOPIC="${NTFY_TOPIC:?Set NTFY_TOPIC to your ntfy.sh topic name before running this}"
GATEWAY_HEALTH_URL="${GATEWAY_HEALTH_URL:-http://127.0.0.1:8000/healthz}"
WORKER_HEALTH_URL="${WORKER_HEALTH_URL:-https://fluent-worker.dionmain.workers.dev/v1/health}"
FAIL_THRESHOLD=3
STATE_DIR="$(dirname "$0")/.health_state"
mkdir -p "$STATE_DIR"

notify() {
  local title="$1" message="$2"
  curl -s -H "Title: $title" -d "$message" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null || true
}

# check NAME URL — probes URL, tracks consecutive failures in $STATE_DIR/NAME,
# alerts on the Nth consecutive failure and once on recovery.
check() {
  local name="$1" url="$2"
  local state_file="$STATE_DIR/$name"
  local fails
  fails="$(cat "$state_file" 2>/dev/null || echo 0)"

  if curl -sf --max-time 10 "$url" >/dev/null 2>&1; then
    if [ "$fails" -ge "$FAIL_THRESHOLD" ]; then
      notify "Fluent: $name recovered" "$name is responding again at $url"
    fi
    echo 0 > "$state_file"
  else
    fails=$((fails + 1))
    echo "$fails" > "$state_file"
    if [ "$fails" -eq "$FAIL_THRESHOLD" ]; then
      notify "Fluent: $name is down" "$name has failed $FAIL_THRESHOLD consecutive health checks ($url)"
    fi
  fi
}

check gateway "$GATEWAY_HEALTH_URL"
check worker "$WORKER_HEALTH_URL"
