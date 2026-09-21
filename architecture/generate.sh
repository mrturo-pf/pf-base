#!/usr/bin/env bash
# Generate architecture/diagram.html from architecture/diagram.json using Archify.
#
# Usage:
#   ./generate.sh            # validate + deliver diagram.html
#   ./generate.sh --open     # also open the result in the default browser
#
# Archify itself is not vendored in this repo (it's a third-party tool, see
# https://github.com/tt-a1i/archify). By default this script looks for it as a
# sibling checkout at ../../archify/archify/bin/archify.mjs (i.e. cloned into
# the parent folder of this repo). Override with ARCHIFY_BIN if you cloned it
# elsewhere:
#
#   ARCHIFY_BIN=/path/to/archify/bin/archify.mjs ./generate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SPEC_FILE="diagram.json"
OUTPUT_FILE="diagram.html"
DEFAULT_ARCHIFY_BIN="$SCRIPT_DIR/../../archify/archify/bin/archify.mjs"
ARCHIFY_BIN="${ARCHIFY_BIN:-$DEFAULT_ARCHIFY_BIN}"

if ! command -v node >/dev/null 2>&1; then
  echo "error: node is required to run Archify (need Node.js >= 18)" >&2
  exit 1
fi

if [[ ! -f "$ARCHIFY_BIN" ]]; then
  echo "error: Archify CLI not found at: $ARCHIFY_BIN" >&2
  echo "" >&2
  echo "Clone it next to this repo, e.g.:" >&2
  echo "  cd $(cd "$SCRIPT_DIR/../.." && pwd)" >&2
  echo "  curl -sL -o archify.zip https://github.com/tt-a1i/archify/archive/refs/heads/main.zip" >&2
  echo "  unzip -q archify.zip && mv archify-main archify && rm archify.zip" >&2
  echo "" >&2
  echo "Or point ARCHIFY_BIN at an existing checkout." >&2
  exit 1
fi

echo "Validating $SPEC_FILE ..."
node "$ARCHIFY_BIN" validate architecture "$SPEC_FILE" --quality showcase --json

echo "Delivering $OUTPUT_FILE ..."
node "$ARCHIFY_BIN" deliver architecture "$SPEC_FILE" "$OUTPUT_FILE" --quality showcase --json

echo "Done: $SCRIPT_DIR/$OUTPUT_FILE"

if [[ "${1:-}" == "--open" ]]; then
  if command -v open >/dev/null 2>&1; then
    open "$OUTPUT_FILE"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$OUTPUT_FILE"
  else
    echo "warn: don't know how to open a browser on this OS, open $OUTPUT_FILE manually" >&2
  fi
fi
