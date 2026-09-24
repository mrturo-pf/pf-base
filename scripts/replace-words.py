#!/usr/bin/env python3
"""replace-words.py - case-sensitive, case-PRESERVING find & replace across
the whole pf ecosystem (this repo + modules/pf-db, pf-rates, pf-payroll,
pf-common, pf-sheets).

Companion to scripts/search-words.sh: reads replacement pairs from the same
scripts/search-words.json config (key "replacements"), and reuses the same
filtering concepts (exclude_files, exclude_dirs, ignore_matches, and the
"respect each MODULE's own .gitignore, never the root repo's" rule -- see
search-words.sh's header comment for the full rationale on that).

Why a separate script instead of extending search-words.sh: writing files
is a fundamentally different (and riskier) responsibility than reporting
matches -- keeping them separate means a bug here can never accidentally
make the read-only search tool destructive, and vice versa.

Casing strategy (deliberately simple, NOT a smart guesser):
  For each {"from": "walmart", "to": "corporative"} pair, exactly 3 casing
  variants are generated and are the ONLY ones ever replaced:
    lower       walmart   -> corporative
    UPPER       WALMART   -> CORPORATIVE
    Capitalized Walmart   -> Corporative   (str.capitalize(): first char
                                             upper, rest lower -- so a
                                             hyphenated base like
                                             "wal-mart" becomes "Wal-mart",
                                             NOT "Wal-Mart". Documented
                                             limitation, not a bug.)
  Anything that doesn't exactly match one of those 3 forms (e.g. "WalMart",
  "wALmart") is left UNTOUCHED and reported separately as "ambiguous casing
  -- review manually". This script never guesses.

Safety:
  - Dry-run by default: only prints a preview, never writes anything.
  - --apply is required to actually write changes to disk.
  - Before writing, checks `git status` for every repo about to be
    touched (root + affected modules) and REFUSES to apply if any of them
    already has uncommitted changes -- pass --force to override. This
    keeps this tool's diff isolated and easy to review/revert.
  - Never commits anything, ever. That's a separate, explicit step.
  - Skips binary files.

Usage:
    scripts/replace-words.py                          # dry-run, from JSON
    scripts/replace-words.py --apply                  # write for real
    scripts/replace-words.py --replace foo=bar         # add an ad hoc pair
    scripts/replace-words.py --exclude-dir secrets     # same flags as
    scripts/replace-words.py --exclude-file '*.csv'    # search-words.sh
    scripts/replace-words.py --ignore-match some-term
    scripts/replace-words.py --apply --force           # skip dirty-repo check

Config (search-words.json, next to this script, gitignored -- see
search-words-example.jsonc for the committed template):
    {
      "replacements": [{"from": "walmart", "to": "corporative"}],
      "exclude_files": [".env"],
      "exclude_dirs": [],
      "ignore_matches": ["walmart-chile"]
    }

Exit codes:
    0 - nothing left to do (dry-run: no pending changes/ambiguities;
        apply: everything resolvable was written, no ambiguities remain)
    1 - dry-run found pending changes and/or ambiguous matches, OR apply
        was refused (dirty repo), OR apply finished but ambiguous matches
        still need manual review
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import subprocess
import sys
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve()
SCRIPT_DIR = SCRIPT_PATH.parent
ROOT_DIR = SCRIPT_DIR.parent
CONFIG_FILE = SCRIPT_DIR / "search-words.json"
MODULES_DIR = ROOT_DIR / "modules"

# Structural baseline -- always skipped, not user-configurable. Mirrors
# search-words.sh's own self-exclusion (this script's config legitimately
# stores the exact words being searched/replaced, so it would otherwise
# always show up as its own match).
STRUCTURAL_EXCLUDE_DIRS = {".git", "logs"}
STRUCTURAL_EXCLUDE_FILES = {
    SCRIPT_PATH.name,
    "search-words.sh",
    "search-words.json",
    "search-words-example.jsonc",
}


def load_config() -> dict:
    if not CONFIG_FILE.exists():
        return {}
    try:
        return json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        sys.exit(f"ERROR: {CONFIG_FILE} is not valid JSON: {exc}")


def discover_module_ignores() -> tuple[set[str], set[str]]:
    """Ask each MODULE's own git repo what it ignores (never the root's --
    see search-words.sh's header comment for why)."""
    dirs: set[str] = set()
    files: set[str] = set()
    if not MODULES_DIR.is_dir():
        return dirs, files
    for module_dir in sorted(MODULES_DIR.iterdir()):
        if not (module_dir / ".git").is_dir():
            continue
        try:
            result = subprocess.run(
                ["git", "-C", str(module_dir), "ls-files", "--others",
                 "--ignored", "--exclude-standard", "--directory"],
                capture_output=True, text=True, check=False,
            )
        except FileNotFoundError:
            return dirs, files  # git not installed -- degrade gracefully
        for entry in result.stdout.splitlines():
            entry = entry.strip()
            if not entry:
                continue
            if entry.endswith("/"):
                dirs.add(Path(entry.rstrip("/")).name)
            else:
                files.add(Path(entry).name)
    return dirs, files


def is_binary(path: Path) -> bool:
    try:
        with path.open("rb") as fh:
            chunk = fh.read(8192)
    except OSError:
        return True
    return b"\0" in chunk


def iter_target_files(exclude_dirs: set[str], exclude_files: set[str]):
    for dirpath, dirnames, filenames in os.walk(ROOT_DIR):
        dirnames[:] = [
            d for d in dirnames
            if not any(fnmatch.fnmatch(d, pat) for pat in exclude_dirs)
        ]
        for name in filenames:
            if any(fnmatch.fnmatch(name, pat) for pat in exclude_files):
                continue
            path = Path(dirpath) / name
            if is_binary(path):
                continue
            yield path


def build_variants(pairs: list[tuple[str, str]]):
    """Returns (variants dict: exact_from_text -> exact_to_text,
    compiled case-insensitive regex matching any base word, or None)."""
    variants: dict[str, str] = {}
    bases: set[str] = set()
    for from_base, to_base in pairs:
        from_base, to_base = from_base.strip(), to_base.strip()
        if not from_base or not to_base:
            continue
        bases.add(from_base.lower())
        variants[from_base.lower()] = to_base.lower()
        variants[from_base.upper()] = to_base.upper()
        variants[from_base.capitalize()] = to_base.capitalize()
    if not bases:
        return variants, None
    ordered = sorted(bases, key=len, reverse=True)  # longest first
    pattern = "|".join(re.escape(b) for b in ordered)
    return variants, re.compile(pattern, re.IGNORECASE)


def process_line(line: str, regex, variants: dict, ignore_matches: list[str]):
    lower_line = line.lower()
    if any(pat.lower() in lower_line for pat in ignore_matches):
        return line, [], []
    if regex is None:
        return line, [], []
    replaced, ambiguous = [], []

    def _sub(match: re.Match) -> str:
        text = match.group(0)
        if text in variants:
            replaced.append(text)
            return variants[text]
        ambiguous.append(text)
        return text

    new_line = regex.sub(_sub, line)
    return new_line, replaced, ambiguous


def process_file(path: Path, regex, variants: dict, ignore_matches: list[str]):
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return None
    lines = text.splitlines(keepends=True)
    changes = []       # (line_no, old_line, new_line)
    ambiguous = []      # (line_no, matched_text)
    new_lines = []
    for i, line in enumerate(lines, start=1):
        new_line, _replaced, amb = process_line(line, regex, variants, ignore_matches)
        ambiguous.extend((i, m) for m in amb)
        if new_line != line:
            changes.append((i, line.rstrip("\n"), new_line.rstrip("\n")))
        new_lines.append(new_line)
    return {
        "changes": changes,
        "ambiguous": ambiguous,
        "new_text": "".join(new_lines) if changes else None,
    }


def repo_root_for(path: Path) -> Path:
    try:
        rel = path.relative_to(MODULES_DIR)
        return MODULES_DIR / rel.parts[0]
    except ValueError:
        return ROOT_DIR


def is_repo_dirty(repo: Path) -> bool:
    result = subprocess.run(
        ["git", "-C", str(repo), "status", "--porcelain"],
        capture_output=True, text=True, check=False,
    )
    return bool(result.stdout.strip())


def parse_args():
    parser = argparse.ArgumentParser(
        description="Case-sensitive find & replace across the pf ecosystem.")
    parser.add_argument("--apply", action="store_true",
                         help="Write changes to disk (default: dry-run).")
    parser.add_argument("--force", action="store_true",
                         help="Apply even if a touched repo has uncommitted changes.")
    parser.add_argument("--exclude-file", action="append", default=[],
                         metavar="PATTERN")
    parser.add_argument("--exclude-dir", action="append", default=[],
                         metavar="PATTERN")
    parser.add_argument("--ignore-match", action="append", default=[],
                         metavar="PATTERN")
    parser.add_argument("--replace", action="append", default=[],
                         metavar="FROM=TO",
                         help="Add an ad hoc replacement pair for this run only.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    config = load_config()

    pairs = [(p["from"], p["to"]) for p in config.get("replacements", [])
             if "from" in p and "to" in p]
    for raw in args.replace:
        if "=" not in raw:
            sys.exit(f"ERROR: --replace expects FROM=TO, got: {raw!r}")
        frm, to = raw.split("=", 1)
        pairs.append((frm, to))

    if not pairs:
        print(f"No replacement pairs configured. Add a \"replacements\" array "
              f"to {CONFIG_FILE.name} or pass --replace FROM=TO.", file=sys.stderr)
        return 1

    exclude_dirs = set(STRUCTURAL_EXCLUDE_DIRS) | set(config.get("exclude_dirs", [])) | set(args.exclude_dir)
    exclude_files = set(STRUCTURAL_EXCLUDE_FILES) | set(config.get("exclude_files", [])) | set(args.exclude_file)
    ignore_matches = list(config.get("ignore_matches", [])) + list(args.ignore_match)

    module_dirs, module_files = discover_module_ignores()
    exclude_dirs |= module_dirs
    exclude_files |= module_files

    variants, regex = build_variants(pairs)

    file_results = {}  # Path -> result dict
    for path in iter_target_files(exclude_dirs, exclude_files):
        result = process_file(path, regex, variants, ignore_matches)
        if result and (result["changes"] or result["ambiguous"]):
            file_results[path] = result

    total_changes = sum(len(r["changes"]) for r in file_results.values())
    total_ambiguous = sum(len(r["ambiguous"]) for r in file_results.values())

    for path, result in sorted(file_results.items()):
        if result["changes"]:
            print(f"\n== {path} ==")
            for line_no, old, new in result["changes"]:
                print(f"  {line_no}: {old.strip()}")
                print(f"     -> {new.strip()}")
        if result["ambiguous"]:
            print(f"\n== {path} (AMBIGUOUS CASING -- left untouched) ==")
            for line_no, text in result["ambiguous"]:
                print(f"  {line_no}: {text!r} doesn't match lower/UPPER/Capitalized exactly")

    print("\n== Summary ==")
    print(f"  {total_changes} replacement(s) across {len(file_results)} file(s)")
    if total_ambiguous:
        print(f"  {total_ambiguous} ambiguous match(es) need manual review (see above)")

    if not args.apply:
        if total_changes or total_ambiguous:
            print("\n  DRY RUN -- nothing written. Re-run with --apply to write these changes.")
            return 1
        print("\n  clean -- nothing to replace.")
        return 0

    # --apply from here on.
    touched_repos = {repo_root_for(p) for p, r in file_results.items() if r["changes"]}
    if not args.force:
        dirty = [r for r in touched_repos if is_repo_dirty(r)]
        if dirty:
            print("\nERROR: refusing to --apply, these repos have uncommitted changes:", file=sys.stderr)
            for r in sorted(dirty):
                print(f"  {r}", file=sys.stderr)
            print("Commit/stash first, or re-run with --force to override.", file=sys.stderr)
            return 1

    written = 0
    for path, result in file_results.items():
        if result["new_text"] is None:
            continue
        path.write_text(result["new_text"], encoding="utf-8")
        written += 1

    print(f"\nApplied: wrote {written} file(s).")
    if total_ambiguous:
        print(f"  {total_ambiguous} ambiguous match(es) still need manual review.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
