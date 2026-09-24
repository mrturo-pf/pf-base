#!/usr/bin/env bash
# ============================================================================
# search-words.sh - case-insensitive word search across the whole pf
#                    ecosystem (this repo + modules/pf-db, pf-rates,
#                    pf-payroll, pf-common, pf-sheets), in code and
#                    comments alike.
#
# Why this exists: modules/ is gitignored at the root repo (each module is
# its own independent git repo), so a plain `git grep` from the root never
# sees inside modules/. This walks the real filesystem tree instead, so it
# always covers everything regardless of git boundaries. Originally built
# to audit "make sure word X never appears anywhere in the ecosystem"
# (e.g. after scrubbing a banned term out of committed files).
#
# Usage:
#   scripts/search-words.sh [--exclude-file PATTERN ...] \
#                            [--exclude-dir PATTERN ...] \
#                            [--ignore-match PATTERN ...] [WORD ...]
#
# Examples:
#   scripts/search-words.sh TODO
#   scripts/search-words.sh TODO FIXME password secret
#   scripts/search-words.sh --exclude-file '*.csv' TODO
#   scripts/search-words.sh                       # uses only search-words.json's "words"
#
# Config file (search-words.json, next to this script -- gitignored):
#   Persistent words/excludes/ignores live in JSON instead of having to
#   retype them as args every run. Copy scripts/search-words-example.jsonc
#   to scripts/search-words.json and edit it -- the example file is the
#   only one committed (a template); your real search-words.json is
#   personal/local and never gets picked up by git. Schema (all keys
#   optional, default []):
#     {
#       "words": ["some-term", "some-other-term"],
#       "exclude_files": [".env"],
#       "exclude_dirs": ["secrets"],
#       "ignore_matches": ["some-term-that-is-fine"]
#     }
#   - words          -> same meaning as a positional WORD argument.
#   - exclude_files  -> same meaning as --exclude-file (basename glob).
#   - exclude_dirs   -> same meaning as --exclude-dir (basename glob).
#   - ignore_matches -> same meaning as --ignore-match (content filter).
#   Requires `jq` (brew install jq) -- only if the JSON file exists.
#   At least one word must come from EITHER the JSON's "words" array OR
#   the command line -- an empty search is refused with a usage message.
#
# --exclude-file / --exclude-dir / --ignore-match flags (repeatable):
#   Same three concepts as the JSON keys above, but ADDED on top of
#   whatever is already in search-words.json for this one run -- handy
#   for a one-off exclusion you don't want to make permanent. Positional
#   WORD arguments work the same way: they're added to (not a replacement
#   for) whatever "words" search-words.json already lists.
#
#   --exclude-file PATTERN: skip files whose BASENAME matches PATTERN
#     (glob, not regex). Matches the exact name only, so ".env" does NOT
#     also skip ".env.default" or ".env.example" -- use ".env*" for that.
#
#   --exclude-dir PATTERN: skip directories whose BASENAME matches
#     PATTERN, anywhere in the tree (same semantics as grep --exclude-dir).
#
#   --ignore-match PATTERN: content-level filter, NOT a file/dir exclude
#     -- drops any result LINE that also contains PATTERN (case
#     insensitive, literal substring), regardless of which file it's in.
#     Use this when a searched word is legitimately part of a bigger term
#     you don't care about (e.g. a compound entity name in seed data).
#
# Automatic .gitignore awareness:
#   Beyond the excludes above, this script asks `git` what each MODULE
#   ignores (modules/pf-db, pf-rates, pf-payroll, pf-common, pf-sheets --
#   each its own git repo with its own .gitignore) and skips those too
#   (.venv, __pycache__, node_modules, coverage, etc.) -- no need to
#   hand-maintain that list, it can never drift out of sync. The ROOT
#   repo's own .gitignore is deliberately NOT consulted: it declares
#   /modules/pf-rates, /modules/pf-payroll, etc. as ignored (so `git
#   status` here stays clean) -- exactly the directories this script
#   exists to search. Respecting it would gut the whole tool.
#
# Notes:
#   - Case-insensitive, literal substring match (--fixed-strings) -- no
#     regex surprises if a word contains ., *, [, etc.
#   - Skips binary files (grep -I).
#   - Exit code: 0 if none of the words were found anywhere, 1 if at least
#     one was -- so this doubles as a pre-commit-style guard, e.g.:
#       scripts/search-words.sh some-banned-term || echo "found leftover mentions!"
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/search-words.json"

# Structural baseline -- always skipped, not user-configurable: .git is
# never meaningful to search, scripts/logs/ is this ecosystem's own
# runtime log output (see pf-services.sh), and this script + its own
# config file are excluded from their own results -- search-words.json
# legitimately stores the exact words/patterns being searched for, so it
# (and this script's header comment showing that JSON as an example)
# would otherwise always show up as a match on itself.
EXCLUDE_DIRS=(.git logs)
EXCLUDE_FILES=("$(basename "${BASH_SOURCE[0]}")" "$(basename "$CONFIG_FILE")")
IGNORE_MATCHES=()
WORDS=()

# Load persistent config from search-words.json, if present.
if [ -f "$CONFIG_FILE" ]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: $CONFIG_FILE exists but 'jq' is not installed (needed to read it)." >&2
    echo "Install it with: brew install jq" >&2
    exit 1
  fi
  if ! jq_err="$(jq empty "$CONFIG_FILE" 2>&1)"; then
    echo "ERROR: $CONFIG_FILE is not valid JSON:" >&2
    echo "$jq_err" >&2
    exit 1
  fi
  while IFS= read -r v; do WORDS+=("$v"); done \
    < <(jq -r '.words[]? // empty' "$CONFIG_FILE")
  while IFS= read -r v; do EXCLUDE_FILES+=("$v"); done \
    < <(jq -r '.exclude_files[]? // empty' "$CONFIG_FILE")
  while IFS= read -r v; do EXCLUDE_DIRS+=("$v"); done \
    < <(jq -r '.exclude_dirs[]? // empty' "$CONFIG_FILE")
  while IFS= read -r v; do IGNORE_MATCHES+=("$v"); done \
    < <(jq -r '.ignore_matches[]? // empty' "$CONFIG_FILE")
fi

# CLI flags ADD to whatever search-words.json already provided above.
while [ "$#" -gt 0 ]; do
  case "$1" in
    --exclude-file)
      if [ -z "${2:-}" ]; then
        echo "ERROR: --exclude-file requires a PATTERN argument" >&2
        exit 1
      fi
      EXCLUDE_FILES+=("$2")
      shift 2
      ;;
    --exclude-dir)
      if [ -z "${2:-}" ]; then
        echo "ERROR: --exclude-dir requires a PATTERN argument" >&2
        exit 1
      fi
      EXCLUDE_DIRS+=("$2")
      shift 2
      ;;
    --ignore-match)
      if [ -z "${2:-}" ]; then
        echo "ERROR: --ignore-match requires a PATTERN argument" >&2
        exit 1
      fi
      IGNORE_MATCHES+=("$2")
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -gt 0 ]; then
  WORDS+=("$@")
fi

if [ "${#WORDS[@]}" -eq 0 ]; then
  echo "Usage: $(basename "$0") [--exclude-file PATTERN ...] [--exclude-dir PATTERN ...] [--ignore-match PATTERN ...] [WORD ...]"
  echo "Case-insensitive search for each WORD across the whole pf ecosystem."
  echo "No words given on the command line, and $(basename "$CONFIG_FILE") has none either -- nothing to search."
  exit 1
fi

# Pull in each MODULE's own .gitignore (never the root repo's -- see the
# header comment above for why). Silently skipped if git isn't installed.
if command -v git >/dev/null 2>&1; then
  for module_dir in "$ROOT_DIR"/modules/*/; do
    module_dir="${module_dir%/}"
    [ -d "$module_dir/.git" ] || continue
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      if [[ "$entry" == */ ]]; then
        EXCLUDE_DIRS+=("$(basename "${entry%/}")")
      else
        EXCLUDE_FILES+=("$(basename "$entry")")
      fi
    done < <(cd "$module_dir" && git ls-files --others --ignored --exclude-standard --directory 2>/dev/null)
  done
fi

GREP_EXCLUDES=()
for dir in "${EXCLUDE_DIRS[@]}"; do
  GREP_EXCLUDES+=(--exclude-dir="$dir")
done
for pattern in "${EXCLUDE_FILES[@]}"; do
  GREP_EXCLUDES+=(--exclude="$pattern")
done

section() { printf '\n== %s ==\n' "$*"; }

overall_found=0

for word in "${WORDS[@]}"; do
  section "Searching: \"$word\""
  matches="$(grep -rniI "${GREP_EXCLUDES[@]}" --fixed-strings -- "$word" "$ROOT_DIR" || true)"
  for ignore in "${IGNORE_MATCHES[@]}"; do
    [ -z "$matches" ] && break
    matches="$(printf '%s\n' "$matches" | grep -vi --fixed-strings -- "$ignore" || true)"
  done
  if [ -z "$matches" ]; then
    echo "  no matches"
  else
    echo "$matches" | sed 's/^/  /'
    count="$(printf '%s\n' "$matches" | wc -l | tr -d ' ')"
    echo ""
    echo "  -> $count match(es)"
    overall_found=1
  fi
done

section "Summary"
if [ "$overall_found" -eq 0 ]; then
  echo "  clean -- none of the given words were found anywhere."
else
  echo "  found at least one match above -- review and fix if needed."
fi

exit "$overall_found"
