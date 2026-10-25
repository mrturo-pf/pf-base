#!/usr/bin/env python3
"""Synchronize the VS Code workspace and the modules repository index.

The workspace includes every local Git checkout. ``modules/INDEX.json`` is a
separate metadata index limited strictly to repositories under ``modules/``.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit, urlunsplit


LANGUAGE_EXTENSIONS: dict[str, str] = {
    ".cjs": "JavaScript",
    ".css": "CSS",
    ".go": "Go",
    ".java": "Java",
    ".js": "JavaScript",
    ".json": "JSON",
    ".jsx": "JavaScript",
    ".py": "Python",
    ".rs": "Rust",
    ".scss": "SCSS",
    ".sql": "SQL",
    ".ts": "TypeScript",
    ".tsx": "TypeScript",
    ".xml": "XML",
    ".yaml": "YAML",
    ".yml": "YAML",
}
CI_MARKERS: tuple[tuple[str, str], ...] = (
    (".github/workflows", "GitHub Actions"),
    ("Jenkinsfile", "Jenkins"),
    (".gitlab-ci.yml", "GitLab CI"),
    ("kitt*.yml", "Kitt"),
    ("kitt*.yaml", "Kitt"),
)
DOCUMENTATION_FILES = {"README.md", "AGENTS.md", "CONTRIBUTING.md", "CHANGELOG.md"}
BUILD_MARKERS: tuple[tuple[str, str], ...] = (
    ("package.json", "npm"),
    ("yarn.lock", "Yarn"),
    ("pnpm-lock.yaml", "pnpm"),
    ("Dockerfile", "Docker"),
    ("Dockerfile.*", "Docker"),
    ("Makefile", "Make"),
    ("pyproject.toml", "Python Packaging"),
    ("requirements.txt", "pip"),
    ("go.mod", "Go Modules"),
    ("Cargo.toml", "Cargo"),
)
TECHNOLOGY_MARKERS: tuple[tuple[str, str], ...] = (
    ("package.json", "Node.js"),
    ("tsconfig.json", "TypeScript"),
    ("Dockerfile", "Docker"),
    ("Dockerfile.*", "Docker"),
    ("pyproject.toml", "Python"),
    ("requirements.txt", "Python"),
    ("go.mod", "Go"),
    ("Cargo.toml", "Rust"),
)

DEFAULT_WORKSPACE_NAME = "pf.code-workspace"
MODULES_DIRECTORY = "modules"
MODULE_INDEX_NAME = "INDEX.json"
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
    return (
        path.is_dir()
        and not path.is_symlink()
        and (git_metadata.is_dir() or git_metadata.is_file())
    )


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


def repository_files(repository: Path) -> list[Path]:
    """List source and configuration files without generated directories."""
    files: list[Path] = []
    for directory, subdirectories, filenames in os.walk(repository):
        subdirectories[:] = [
            name for name in subdirectories if name not in IGNORED_DIRECTORIES
        ]
        files.extend(Path(directory) / name for name in filenames)
    return files


def git_output(repository: Path, *arguments: str) -> str | None:
    """Return trimmed Git output, or ``None`` when the command fails."""
    result = subprocess.run(
        ["git", "-C", str(repository), *arguments],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def repository_url(repository: Path) -> str | None:
    """Return the origin URL without exposing embedded credentials."""
    url = git_output(repository, "config", "--get", "remote.origin.url")
    if not url:
        return None
    parsed = urlsplit(url)
    if parsed.username or parsed.password:
        hostname = parsed.hostname or ""
        if parsed.port:
            hostname += f":{parsed.port}"
        return urlunsplit((parsed.scheme, f"[REDACTED]@{hostname}", parsed.path, parsed.query, parsed.fragment))
    return url


def repository_git_metadata(repository: Path) -> dict[str, Any]:
    """Collect useful local Git state without contacting the remote."""
    metadata: dict[str, Any] = {
        "currentBranch": git_output(repository, "branch", "--show-current") or None,
        "workingTreeClean": git_output(repository, "status", "--porcelain") == "",
    }
    commit = git_output(repository, "log", "-1", "--format=%H%x1f%cI%x1f%s")
    if commit:
        commit_hash, date, subject = commit.split("\x1f", maxsplit=2)
        metadata["lastCommit"] = {"hash": commit_hash, "date": date, "subject": subject}
    upstream = git_output(
        repository, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"
    )
    if upstream:
        divergence = git_output(repository, "rev-list", "--left-right", "--count", f"HEAD...{upstream}")
        if divergence:
            ahead, behind = divergence.split()
            metadata["tracking"] = {"branch": upstream, "ahead": int(ahead), "behind": int(behind)}
    return metadata


def repository_metadata(root: Path, repository: Path) -> dict[str, Any]:
    """Build deterministic metadata for one repository under ``modules``."""
    files = repository_files(repository)
    languages = sorted(
        {LANGUAGE_EXTENSIONS[file.suffix.lower()] for file in files if file.suffix.lower() in LANGUAGE_EXTENSIONS},
        key=str.casefold,
    )
    ci = {
        provider
        for marker, provider in CI_MARKERS
        if (repository / marker).exists()
        or any(file.relative_to(repository).as_posix().startswith(f"{marker}/") for file in files)
    }
    documentation = {file.name for file in files if file.name in DOCUMENTATION_FILES}
    build_systems = {
        system for pattern, system in BUILD_MARKERS if any(fnmatch.fnmatch(file.name, pattern) for file in files)
    }
    technologies = {
        technology for pattern, technology in TECHNOLOGY_MARKERS
        if any(fnmatch.fnmatch(file.name, pattern) for file in files)
    }
    for file in (file for file in files if file.name in {"package.json", "pyproject.toml"}):
        content = file.read_text(encoding="utf-8", errors="ignore").lower()
        if file.name == "package.json" and "react" in content:
            technologies.add("React")
    entry: dict[str, Any] = {
        "name": repository.name,
        "path": relative_path(root, repository),
        "technologies": sorted(technologies, key=str.casefold),
        "languages": languages,
        "ci": sorted(ci, key=str.casefold),
        "documentation": sorted(documentation, key=str.casefold),
        "buildSystems": sorted(build_systems, key=str.casefold),
        **repository_git_metadata(repository),
    }
    url = repository_url(repository)
    if url is not None:
        entry["url"] = url
    return entry


def module_repositories(root: Path) -> list[Path]:
    """Find only direct Git checkouts below ``modules``."""
    modules = root / MODULES_DIRECTORY
    if not modules.is_dir():
        return []
    return [
        path for path in sorted(modules.iterdir(), key=lambda item: item.name.casefold())
        if is_git_checkout(path)
    ]


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


def render(value: Any) -> str:
    """Render JSON deterministically."""
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
    module_paths = module_repositories(root)
    index_path = root / MODULES_DIRECTORY / MODULE_INDEX_NAME
    current = read_workspace(workspace_path)
    desired_workspace = render(expected_workspace(current, root, checkout_paths))
    desired_index = render([repository_metadata(root, path) for path in module_paths])
    existing_workspace = workspace_path.read_text(encoding="utf-8") if workspace_path.exists() else ""
    existing_index = index_path.read_text(encoding="utf-8") if index_path.exists() else ""
    workspace_changed = desired_workspace != existing_workspace
    index_changed = desired_index != existing_index

    log(arguments.quiet, "DISCOVERY", f"repositories={len(checkout_paths)} modules={len(module_paths)}")
    for repository in checkout_paths:
        log(arguments.quiet, "REPOSITORY", f"{repository.name} ({relative_path(root, repository)})")
    log(arguments.quiet, "CHANGES", f"workspace={workspace_changed} index={index_changed}")

    if arguments.check:
        if workspace_changed:
            log(arguments.quiet, "CHECK", f"workspace is out of date: {workspace_path}")
        if index_changed:
            log(arguments.quiet, "CHECK", f"module index is out of date: {index_path}")
        if not workspace_changed and not index_changed:
            log(arguments.quiet, "CHECK", "workspace and module index are up to date")
        return int(workspace_changed or index_changed)

    if workspace_changed:
        workspace_path.parent.mkdir(parents=True, exist_ok=True)
        write_atomically(workspace_path, desired_workspace)
        log(arguments.quiet, "WRITE", f"workspace updated: {workspace_path}")
    else:
        log(arguments.quiet, "SKIP", "workspace already up to date")
    if index_changed:
        index_path.parent.mkdir(parents=True, exist_ok=True)
        write_atomically(index_path, desired_index)
        log(arguments.quiet, "WRITE", f"module index updated: {index_path}")
    else:
        log(arguments.quiet, "SKIP", "module index already up to date")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
