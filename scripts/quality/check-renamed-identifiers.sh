#!/usr/bin/env bash
# Audit legacy identifiers across the complete PF ecosystem.
#
# Usage:
#   scripts/quality/check-renamed-identifiers.sh
#   scripts/quality/check-renamed-identifiers.sh period_year period_month PAY_PERIOD
#
# Exit status:
#   0: no legacy identifier was found
#   1: one or more matches were found
#   2: invalid invocation or missing dependency
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if ! command -v grep >/dev/null 2>&1; then
  printf 'ERROR: grep is required\n' >&2
  exit 2
fi

if [ "$#" -eq 0 ]; then
  IDENTIFIERS=(period_year period_month)
else
  IDENTIFIERS=("$@")
fi

# These directories contain generated/runtime noise rather than source-of-truth
# code or documentation. Modules are intentionally searched even though the
# root repository ignores them, because each module is an independent repo.
EXCLUDED_DIRS=(
  .git
  .venv
  __pycache__
  node_modules
  coverage
  htmlcov
  logs
  build
  dist
  '*.egg-info'
)

GREP_ARGS=()
for directory in "${EXCLUDED_DIRS[@]}"; do
  GREP_ARGS+=(--exclude-dir="$directory")
done

found=0
for identifier in "${IDENTIFIERS[@]}"; do
  printf '\n== Legacy identifier: %s ==\n' "$identifier"
  matches="$(grep -rniI --fixed-strings "${GREP_ARGS[@]}" -- "$identifier" "$ROOT_DIR" || true)"
  if [ -z "$matches" ]; then
    printf 'clean\n'
    continue
  fi

  found=1
  printf '%s\n' "$matches"
  printf '%s\n' "Matches found: $(printf '%s\n' "$matches" | wc -l | tr -d ' ')"
done

if [ "$found" -eq 1 ]; then
  printf '\nLegacy identifiers remain. Review each match and annotate intentional historical references before renaming.\n' >&2
  exit 1
fi

printf '\nNo legacy identifiers found.\n'
