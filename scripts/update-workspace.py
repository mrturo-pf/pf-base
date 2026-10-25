#!/usr/bin/env python3
"""Synchronize ``pf.code-workspace`` with local Git repositories.

The workspace file is the only generated artifact. Repository metadata is not
stored in an index: every run discovers Git checkouts directly below the
workspace root and adds one VS Code folder for each checkout.
"""

from __future__ import annotations

import argparse
import json
import os
import tempfile
from pathlib import Path
from typing import Any


DEFAULT_WORKSPACE_NAME = "pf.code-workspace"
IGNORED_DIRECTORIES = {
    ".git",
    ".venv",
    "__pycache__",
    "build",
    "dist",
    "node_modules",
    "target",
}


def parse_args() -> argparse.Namespace:
    """Parse workspace synchronization options."""
    parser = argparse.ArgumentParser(
        description="Update pf.code-workspace with local Git repositories."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="Workspace root (defaults to the repository containing this script).",
    )
    parser.add_argument(
        "--workspace",
        type=Path,
        default=None,
        help="Workspace file (defaults to <root>/pf.code-workspace).",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Report whether the workspace is current without changing it.",
    )
    parser.add_argument("--quiet", action="store_true", help="Suppress status output.")
    return parser.parse_args()


def is_git_checkout(path: Path) -> bool:
    """Return whether ``path`` is a regular or linked Git checkout."""
    git_metadata = path / ".git"
    return path.is_dir() and (git_metadata.is_dir() or git_metadata.is_file())


def repositories(root: Path) -> list[Path]:
    """Find Git checkouts recursively, without descending into another checkout."""
    found: list[Path] = []
    for directory, subdirectories, _ in os.walk(root, topdown=True, followlinks=False):
        current = Path(directory)
        subdirectories[:] = sorted(
            (name for name in subdirectories if name not in IGNORED_DIRECTORIES),
            key=str.casefold,
        )
        if current == root:
            continue
        if is_git_checkout(current):
            found.append(current)
            subdirectories[:] = []
    return sorted(found, key=lambda path: path.relative_to(root).as_posix().casefold())


def relative_path(root: Path, repository: Path) -> str:
    """Return a portable workspace-relative path."""
    return repository.relative_to(root).as_posix()


def expected_workspace(
    current: dict[str, Any] | None, root: Path, checkout_paths: list[Path]
) -> dict[str, Any]:
    """Build the workspace document while preserving unrelated settings."""
    workspace = dict(current or {})
    workspace["folders"] = [
        {"name": root.name, "path": "."},
        *[
            {"name": repository.name, "path": relative_path(root, repository)}
            for repository in checkout_paths
        ],
    ]
    workspace.setdefault("settings", {})
    return workspace


def read_workspace(path: Path) -> dict[str, Any] | None:
    """Read a workspace JSON object, or return ``None`` when it is absent."""
    if not path.exists():
        return None
    with path.open(encoding="utf-8") as file:
        value = json.load(file)
    if not isinstance(value, dict):
        raise ValueError(f"Workspace file must contain a JSON object: {path}")
    return value


def render(value: dict[str, Any]) -> str:
    """Render workspace JSON deterministically."""
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def write_atomically(path: Path, content: str) -> None:
    """Replace a file atomically so an interrupted run cannot truncate it."""
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as file:
            file.write(content)
        os.replace(temporary_name, path)
    except BaseException:
        Path(temporary_name).unlink(missing_ok=True)
        raise


def log(quiet: bool, tag: str, message: str) -> None:
    """Print a tagged message unless quiet mode was requested."""
    if not quiet:
        print(f"[{tag}] {message}")


def main() -> int:
    """Discover repositories and synchronize the workspace file."""
    arguments = parse_args()
    root = arguments.root.resolve()
    workspace_path = (arguments.workspace or root / DEFAULT_WORKSPACE_NAME).resolve()
    checkout_paths = repositories(root)
    current = read_workspace(workspace_path)
    desired = render(expected_workspace(current, root, checkout_paths))
    existing = workspace_path.read_text(encoding="utf-8") if workspace_path.exists() else ""
    changed = desired != existing

    log(arguments.quiet, "DISCOVERY", f"repositories={len(checkout_paths)}")
    for repository in checkout_paths:
        log(arguments.quiet, "REPOSITORY", f"{repository.name} ({relative_path(root, repository)})")
    log(arguments.quiet, "CHANGES", f"workspace={changed}")

    if arguments.check:
        log(arguments.quiet, "CHECK", "workspace is out of date" if changed else "workspace is up to date")
        return int(changed)
    if changed:
        workspace_path.parent.mkdir(parents=True, exist_ok=True)
        write_atomically(workspace_path, desired)
        log(arguments.quiet, "WRITE", f"workspace updated: {workspace_path}")
    else:
        log(arguments.quiet, "SKIP", "workspace already up to date")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
