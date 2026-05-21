#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${ANTHROPIC_API_KEY:-}" && -f "/Users/Karthik/Documents/work/stalker-mac/.env" ]]; then
  set -a
  # Private local key file. Do not print values from this file.
  source "/Users/Karthik/Documents/work/stalker-mac/.env"
  set +a
fi

xcodebuild \
  -project Pensieve.xcodeproj \
  -scheme Pensieve \
  -destination 'generic/platform=iOS Simulator' \
  build

python3 scripts/test_with_icloud_vault.py --require-llm
