#!/usr/bin/env bash
# Generate architecture/<name>.html from its Archify spec.
#
# Usage:
#   ./generate.sh                    # ecosystem: base.json -> base.html
#   ./generate.sh pf-payroll         # per-app:    pf-payroll.architecture.json -> pf-payroll.html
#   ./generate.sh pf-payroll --open  # same, then open the result in the default browser
#
# Per-app diagrams carry `meta.repository` (Archify's repository-evidence
# feature): every component `sources` entry is verified against real git
# blobs in that subproject's own checkout. This script auto-detects the repo
# root as ../modules/<name> (skipped if that's not a git repo, e.g. the
# ecosystem-wide "base" diagram itself). Override with REPO_ROOT if needed.
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

NAME="base"
OPEN_AFTER=0
for arg in "$@"; do
  case "$arg" in
    --open) OPEN_AFTER=1 ;;
    *) NAME="$arg" ;;
  esac
done

if [[ "$NAME" == "base" ]]; then
  SPEC_FILE="base.json"
else
  SPEC_FILE="${NAME}.architecture.json"
fi
OUTPUT_FILE="${NAME}.html"

DEFAULT_ARCHIFY_BIN="$SCRIPT_DIR/../../archify/archify/bin/archify.mjs"
ARCHIFY_BIN="${ARCHIFY_BIN:-$DEFAULT_ARCHIFY_BIN}"

DEFAULT_REPO_ROOT="$SCRIPT_DIR/../modules/$NAME"
REPO_ROOT="${REPO_ROOT:-$DEFAULT_REPO_ROOT}"
REPO_ROOT_ARGS=()
if [[ -d "$REPO_ROOT/.git" ]]; then
  REPO_ROOT_ARGS=(--repo-root "$REPO_ROOT")
fi

if ! command -v node >/dev/null 2>&1; then
  echo "error: node is required to run Archify (need Node.js >= 18)" >&2
  exit 1
fi

if [[ ! -f "$SPEC_FILE" ]]; then
  echo "error: spec file not found: $SCRIPT_DIR/$SPEC_FILE" >&2
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
node "$ARCHIFY_BIN" validate architecture "$SPEC_FILE" ${REPO_ROOT_ARGS[@]+"${REPO_ROOT_ARGS[@]}"} --quality showcase --json

echo "Delivering $OUTPUT_FILE ..."
node "$ARCHIFY_BIN" deliver architecture "$SPEC_FILE" "$OUTPUT_FILE" ${REPO_ROOT_ARGS[@]+"${REPO_ROOT_ARGS[@]}"} --quality showcase --json

echo "Done: $SCRIPT_DIR/$OUTPUT_FILE"

if [[ "$OPEN_AFTER" == "1" ]]; then
  if command -v open >/dev/null 2>&1; then
    open "$OUTPUT_FILE"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$OUTPUT_FILE"
  else
    echo "warn: don't know how to open a browser on this OS, open $OUTPUT_FILE manually" >&2
  fi
fi
