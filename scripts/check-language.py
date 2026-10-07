#!/usr/bin/env python3
"""Check that prose documentation uses the ecosystem's required language.

The checker is intentionally conservative: it reports likely Spanish prose, not
isolated accented words or official Chilean terminology. It has no third-party
runtime dependency so hooks work in fresh checkouts.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
POLICY = ROOT / "scripts" / "language-policy.txt"
SPANISH_STOPWORDS = {
    "a", "al", "con", "como", "cual", "cuando", "de", "del", "desde",
    "donde", "el", "ella", "ellas", "ellos", "en", "entre", "es", "esta",
    "este", "estos", "la", "las", "lo", "los", "más", "para", "por",
    "que", "se", "sin", "son", "su", "sus", "también", "una", "uno",
    "y", "ya",
}
ENGLISH_STOPWORDS = {
    "a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "in",
    "is", "it", "of", "on", "or", "that", "the", "these", "this", "to",
    "with",
}
WORD_RE = re.compile(r"[A-Za-zÀ-ÿ]+(?:['’-][A-Za-zÀ-ÿ]+)?")
HEADING_RE = re.compile(r"^\s{0,3}#{1,6}\s+")
CODE_FENCE_RE = re.compile(r"^\s*(```|~~~)")
COMMENT_PREFIXES = ("<!--", "//", "# ")


def load_policy() -> tuple[set[str], set[str]]:
    """Load exact path and term exclusions from the simple policy file."""
    paths: set[str] = set()
    terms: set[str] = set()
    if not POLICY.exists():
        return paths, terms
    section = None
    for raw_line in POLICY.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section not in {"paths", "terms"}:
            continue
        if "=" in line:
            value = line.split("=", 1)[1].strip().strip('"')
        else:
            value = line.strip('"')
        (paths if section == "paths" else terms).add(value.lower())
    return paths, terms


def git_root() -> Path:
    """Return the current repository root, supporting module checkouts."""
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=True,
    )
    return Path(result.stdout.strip())


def candidate_files(repo: Path, mode: str) -> list[Path]:
    """Return Markdown files from the whole repo or its staged index."""
    if mode == "staged":
        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
            cwd=repo,
            capture_output=True,
            text=True,
            check=True,
        )
        names = [Path(name) for name in result.stdout.splitlines()]
    else:
        names = [path.relative_to(repo) for path in repo.rglob("*.md")]
    ignored = {".git", ".venv", "node_modules", "dist", "build", "coverage"}
    return [
        repo / name
        for name in names
        if name.suffix.lower() in {".md", ".mdx"}
        and not any(part in ignored for part in name.parts)
    ]


def prose_lines(path: Path):
    """Yield (line number, prose) while excluding fenced code blocks."""
    fenced = False
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if CODE_FENCE_RE.match(line):
            fenced = not fenced
            continue
        if fenced or line.startswith(("    ", "\t")):
            continue
        if line.lstrip().startswith(COMMENT_PREFIXES):
            continue
        yield number, line


def score(line: str, allowed_terms: set[str]) -> tuple[int, int, list[str]]:
    """Return Spanish indicators, English indicators, and matched words."""
    words = [word.lower() for word in WORD_RE.findall(line)]
    filtered = [word for word in words if word not in allowed_terms]
    spanish = [word for word in filtered if word in SPANISH_STOPWORDS]
    english = [word for word in filtered if word in ENGLISH_STOPWORDS]
    accented = [word for word in filtered if re.search(r"[áéíóúüñ]", word)]
    return len(spanish) + min(len(accented), 2), len(english), spanish + accented[:2]


def inspect(path: Path, repo: Path, allowed_terms: set[str]):
    """Return suspicious lines and aggregate indicators for one file."""
    suspicious = []
    spanish_total = english_total = prose_words = 0
    for number, line in prose_lines(path):
        if not line.strip() or line.lstrip().startswith("|"):
            continue
        words = WORD_RE.findall(line)
        if len(words) < 4:
            continue
        spanish, english, matches = score(line, allowed_terms)
        spanish_total += spanish
        english_total += english
        prose_words += len(words)
        if spanish >= 3 and spanish > english:
            suspicious.append((number, line.strip(), matches))
    # A document is a failure only with repeated evidence, avoiding one-off
    # Spanish terms in otherwise English documentation.
    threshold = 1 if prose_words < 80 else max(2, min(6, prose_words // 80))
    return suspicious, spanish_total, english_total, threshold


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--staged", action="store_true", help="check staged Markdown only")
    parser.add_argument("--all", action="store_true", help="check all Markdown in the current repository")
    parser.add_argument("--report", action="store_true", help="report findings without failing")
    args = parser.parse_args()
    if args.staged and args.all:
        parser.error("choose only one of --staged or --all")
    mode = "staged" if args.staged or not args.all else "all"
    repo = git_root()
    excluded_paths, allowed_terms = load_policy()
    files = [path for path in candidate_files(repo, mode) if path.exists()]
    failures = 0
    for path in files:
        relative = path.relative_to(repo).as_posix().lower()
        if relative in excluded_paths:
            continue
        try:
            suspicious, spanish, english, threshold = inspect(path, repo, allowed_terms)
        except UnicodeDecodeError:
            continue
        if len(suspicious) < threshold:
            continue
        failures += 1
        print(f"\n{path.relative_to(repo)}: likely Spanish prose")
        print(f"  indicators: Spanish={spanish}, English={english}, suspicious_lines={len(suspicious)}")
        for number, line, matches in suspicious[:8]:
            print(f"  {number}: {line}")
            print(f"     indicators: {', '.join(matches)}")
    if not failures:
        print(f"Language check passed ({len(files)} Markdown files checked).")
        return 0
    print(f"\nLanguage check found {failures} likely Spanish Markdown file(s).")
    print(f"Review {POLICY.relative_to(ROOT)} for narrowly scoped exceptions.")
    return 0 if args.report else 1


if __name__ == "__main__":
    sys.exit(main())
