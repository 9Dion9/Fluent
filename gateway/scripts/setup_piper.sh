#!/usr/bin/env bash
# Downloads the Piper binary + voice models this gateway depends on.
# Not committed to git (large binaries) — run once per machine. See docs/RUNBOOK.md.
set -euo pipefail
cd "$(dirname "$0")/.."

PIPER_RELEASE="https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_linux_x86_64.tar.gz"
VOICES_BASE="https://huggingface.co/rhasspy/piper-voices/resolve/main"

mkdir -p bin voices

if [ ! -x bin/piper/piper ]; then
  echo "Downloading Piper binary..."
  curl -sL -o /tmp/piper.tar.gz "$PIPER_RELEASE"
  tar xzf /tmp/piper.tar.gz -C bin
  rm /tmp/piper.tar.gz
fi

download_voice() {
  local rel_path="$1" name="$2"
  if [ ! -f "voices/${name}.onnx" ]; then
    echo "Downloading voice: ${name}..."
    curl -sL -o "voices/${name}.onnx" "${VOICES_BASE}/${rel_path}/${name}.onnx"
    curl -sL -o "voices/${name}.onnx.json" "${VOICES_BASE}/${rel_path}/${name}.onnx.json"
  fi
}

download_voice "de/de_DE/thorsten/high" "de_DE-thorsten-high"
download_voice "en/en_US/lessac/high" "en_US-lessac-high"

echo "Piper setup complete: $(bin/piper/piper --help 2>&1 | head -1 || true)"
