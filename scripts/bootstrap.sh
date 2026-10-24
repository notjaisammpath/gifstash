#!/usr/bin/env bash
# Generates GifStash.xcodeproj and opens it. Run from the repo root.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is not installed. Install it with:" >&2
  echo "  brew install xcodegen" >&2
  exit 1
fi

if [[ ! -f Config/Secrets.xcconfig ]]; then
  cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
  echo "Created Config/Secrets.xcconfig - add your GIPHY key before building."
fi

xcodegen generate
echo "Generated GifStash.xcodeproj"

if [[ "${1:-}" != "--no-open" ]]; then
  open GifStash.xcodeproj
fi
