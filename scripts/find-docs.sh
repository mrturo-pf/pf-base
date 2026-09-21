#!/usr/bin/env bash
# find-docs.sh — list all *.md, *.txt, and *.sh files recursively, skipping noise dirs by default.
#
# Usage:
#   ./scripts/find-docs.sh [-d DIR] [-i FILE1,FILE2,...] [-h]
#
# Options:
#   -d, --dir DIR       Directory to search (default: current directory)
#   -i, --ignore LIST   Comma-separated filenames to exclude (e.g. AGENTS.md,README.md)
#   -h, --help          Show this help message
#
# Examples:
#   ./scripts/find-docs.sh
#   ./scripts/find-docs.sh -d modules/pf-rates
#   ./scripts/find-docs.sh -i AGENTS.md,README.md
#   ./scripts/find-docs.sh -d modules/pf-payroll -i README.md

set -euo pipefail

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

DIR="."
IGNORE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dir)
      DIR="$2"
      shift 2
      ;;
    -i|--ignore)
      IGNORE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# Noise directories skipped unconditionally — nobody wants venv/git internals in the list.
# The script also skips itself: now that *.sh is in scope, it would otherwise
# always list its own path.
EXCLUDE_ARGS=(
  -not -path "*/.venv/*"
  -not -path "*/venv/*"
  -not -path "*/.git/*"
  -not -path "*/.pytest_cache/*"
  -not -path "*/node_modules/*"
  -not -path "*.egg-info/*"
  -not -name "$(basename "$0")"
)

# Turn "AGENTS.md,README.md" into -not -name AGENTS.md -not -name README.md
if [[ -n "$IGNORE" ]]; then
  IFS=',' read -ra IGNORE_ITEMS <<< "$IGNORE"
  for item in "${IGNORE_ITEMS[@]}"; do
    EXCLUDE_ARGS+=(-not -name "$item")
  done
fi

find "$DIR" \( -name "*.md" -o -name "*.txt" -o -name "*.sh" \) "${EXCLUDE_ARGS[@]}" | sort
