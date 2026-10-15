#!/usr/bin/env python3
"""Plan safe PF repository branch, push, PR, and cleanup actions.

Default mode is read-only. GitHub is authoritative for PR merge state because
squash/rebase merges do not preserve source commit IDs in the default branch.
"""
from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import sys
from datetime import datetime, timezone
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
REPOSITORIES = {
    "pf-base": ".", "pf-postman": "postman", "pf-improvements": "improvements",
    "pf-db": "modules/pf-db", "pf-rates": "modules/pf-rates",
    "pf-payroll": "modules/pf-payroll", "pf-common": "modules/pf-common",
    "pf-sheets": "modules/pf-sheets",
}
PROTECTED = {"main", "master", "develop"}
PR_FIELDS = "number,state,mergedAt,headRefName,headRefOid,baseRefName,isCrossRepository,url"
STRIP_NETWORK_ENV = True


@dataclass
class Action:
    repo: str
    branch: str
    kind: str
    reason: str
    local_sha: str | None = None
    pr_sha: str | None = None
    remote_sha: str | None = None


@dataclass
class RepoState:
    repo: str
    path: str
    default_branch: str
    current: str
    dirty: bool
    actions: list[Action] = field(default_factory=list)


def env_without_network_overrides() -> dict[str, str]:
    env = os.environ.copy()
    if not STRIP_NETWORK_ENV:
        return env
    for key in list(env):
        if key.lower() in {"http_proxy", "https_proxy", "all_proxy", "no_proxy"}:
            env.pop(key, None)
    env.pop("SSL_CERT_FILE", None)
    env.pop("_SSL_CERT_FILE", None)
    return env


def run(command: list[str], *, check: bool = True) -> str:
    result = subprocess.run(command, env=env_without_network_overrides(), text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if check and result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"{shlex.join(command)} failed: {detail}")
    return result.stdout.strip()


def git(path: Path, *args: str, check: bool = True) -> str:
    return run(["git", "-C", str(path), *args], check=check)


def github_repo(path: Path) -> str:
    url = git(path, "remote", "get-url", "origin").removesuffix(".git")
    if url.startswith("git@github.com:"):
        return url.removeprefix("git@github.com:")
    if "github.com/" in url:
        return url.split("github.com/", 1)[1]
    raise RuntimeError(f"origin is not a GitHub remote: {url}")


def default_branch(path: Path, slug: str) -> str:
    ref = git(path, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD", check=False)
    if ref.startswith("origin/"):
        return ref.removeprefix("origin/")
    name = run(["gh", "repo", "view", slug, "--json", "defaultBranchRef", "--jq", ".defaultBranchRef.name"])
    if not name:
        raise RuntimeError(f"cannot determine default branch for {slug}")
    return name


def prs(slug: str, branch: str) -> list[dict[str, Any]]:
    raw = run(["gh", "pr", "list", "--repo", slug, "--state", "all", "--head", branch,
               "--json", PR_FIELDS, "--limit", "50"])
    records = [p for p in json.loads(raw or "[]") if not p.get("isCrossRepository")]
    return sorted(records, key=lambda p: p.get("number", 0), reverse=True)


def active_runs(slug: str, branch: str) -> list[dict[str, Any]]:
    raw = run(["gh", "run", "list", "--repo", slug, "--branch", branch,
               "--json", "databaseId,name,status", "--limit", "50"])
    return [run_info for run_info in json.loads(raw or "[]") if run_info.get("status") != "completed"]


def dependent_prs(slug: str, branch: str) -> list[dict[str, Any]]:
    raw = run(["gh", "pr", "list", "--repo", slug, "--state", "open", "--base", branch,
               "--json", PR_FIELDS, "--limit", "50"])
    return json.loads(raw or "[]")


def remote_sha(path: Path, branch: str) -> str | None:
    value = git(path, "rev-parse", "--verify", "--quiet", f"refs/remotes/origin/{branch}", check=False)
    return value or None


def branch_names(path: Path) -> tuple[list[str], list[str]]:
    local = git(path, "for-each-ref", "refs/heads", "--format=%(refname:short)").splitlines()
    remote = git(path, "for-each-ref", "refs/remotes/origin", "--format=%(refname:short)").splitlines()
    remote = [b.removeprefix("origin/") for b in remote if b not in {"origin", "origin/HEAD"}]
    return local, remote


def add(state: RepoState, branch: str, kind: str, reason: str, **sha: str | None) -> None:
    state.actions.append(Action(state.repo, branch, kind, reason, **sha))


def gh_api_optional(endpoint: str) -> Any | None:
    try:
        raw = run(["gh", "api", endpoint])
    except RuntimeError as error:
        if "404" in str(error):
            return None
        raise
    return json.loads(raw) if raw else None


def protection_report(slug: str, branch: str) -> dict[str, Any]:
    """Read classic branch protection and repository rulesets."""
    classic = gh_api_optional(f"repos/{slug}/branches/{branch}/protection")
    rulesets = gh_api_optional(f"repos/{slug}/rules/branches/{branch}") or []
    sources: list[str] = []
    checks: list[str] = []
    pr_required = False
    reviews = 0
    conversations = False
    force_blocked = False
    deletions_blocked = False
    if classic:
        sources.append("branch_protection")
        pull_reviews = classic.get("required_pull_request_reviews") or {}
        pr_required |= bool(pull_reviews)
        reviews = max(reviews, pull_reviews.get("required_approving_review_count", 0))
        status = classic.get("required_status_checks") or {}
        checks.extend(status.get("checks") and [item["context"] for item in status["checks"]] or status.get("contexts", []))
        conversations |= bool((classic.get("required_conversation_resolution") or {}).get("enabled"))
        force_blocked |= not (classic.get("allow_force_pushes") or {}).get("enabled")
        deletions_blocked |= not (classic.get("allow_deletions") or {}).get("enabled")
    if rulesets:
        sources.append("rulesets")
        for rule in rulesets:
            rule_type = rule.get("type")
            params = rule.get("parameters") or {}
            if rule_type == "pull_request":
                pr_required = True
                reviews = max(reviews, params.get("required_approving_review_count", 0))
                conversations |= bool(params.get("required_review_thread_resolution"))
            elif rule_type == "required_status_checks":
                checks.extend(item.get("context", "") for item in params.get("required_status_checks", []))
            elif rule_type == "non_fast_forward":
                force_blocked = True
            elif rule_type == "deletion":
                deletions_blocked = True
    return {
        "protected": bool(sources), "branch": branch, "sources": sources,
        "pull_request_required": pr_required, "required_reviews": reviews,
        "required_checks": sorted(set(filter(None, checks))),
        "conversation_resolution_required": conversations,
        "force_pushes_allowed": not force_blocked,
        "deletions_allowed": not deletions_blocked,
    }


def inspect_branch(state: RepoState, path: Path, slug: str, branch: str, local: bool) -> None:
    if branch in PROTECTED or branch == state.default_branch:
        return
    local_sha = git(path, "rev-parse", branch, check=False) if local else None
    remote_tip = remote_sha(path, branch)
    records = prs(slug, branch)
    branch_tip = local_sha or remote_tip
    opened = next((p for p in records if p["state"] == "OPEN"), None)
    merged = next((p for p in records if p["state"] == "MERGED"), None)
    closed = next((p for p in records if p["state"] == "CLOSED" and p.get("headRefOid") == branch_tip), None)

    if opened:
        add(state, branch, "WAIT", f"open PR #{opened['number']}: {opened['url']}", local_sha=local_sha, remote_sha=remote_tip)
        return
    if closed:
        add(state, branch, "BLOCK", f"closed unmerged PR #{closed['number']}; human review required", local_sha=local_sha, remote_sha=remote_tip)
        return
    if merged:
        pr_sha = merged["headRefOid"]
        if local_sha is None:
            add(state, branch, "BLOCK", f"merged PR #{merged['number']} is remote-only; local checkout required before cleanup", pr_sha=pr_sha, remote_sha=remote_tip)
        elif local_sha != pr_sha:
            add(state, branch, "BLOCK", f"merged PR #{merged['number']} head differs from local HEAD", local_sha=local_sha, pr_sha=pr_sha, remote_sha=remote_tip)
        elif remote_tip and remote_tip != pr_sha:
            add(state, branch, "BLOCK", f"merged PR #{merged['number']} head differs from remote tip", local_sha=local_sha, pr_sha=pr_sha, remote_sha=remote_tip)
        else:
            dependents = dependent_prs(slug, branch)
            if dependents:
                numbers = ", ".join(f"#{p['number']}" for p in dependents)
                add(state, branch, "BLOCK", f"open dependent PRs use this branch as base: {numbers}", local_sha=local_sha, remote_sha=remote_tip)
                return
            add(state, branch, "CLEANUP", f"merged PR #{merged['number']} matches branch tip", local_sha=local_sha, pr_sha=pr_sha, remote_sha=remote_tip)
        return
    if not local:
        add(state, branch, "WAIT", "remote-only branch has no PR; never delete automatically", remote_sha=remote_tip)
        return
    upstream = git(path, "for-each-ref", f"refs/heads/{branch}", "--format=%(upstream:short)")
    expected = f"origin/{branch}"
    if upstream and upstream != expected:
        add(state, branch, "BLOCK", f"upstream is {upstream}; expected {expected}", local_sha=local_sha, remote_sha=remote_tip)
        return
    if local and remote_tip:
        left, right = (int(v) for v in git(path, "rev-list", "--left-right", "--count", f"{expected}...{branch}").split())
        if left and right:
            add(state, branch, "BLOCK", f"local and remote branches diverged ({right} ahead, {left} behind)", local_sha=local_sha, remote_sha=remote_tip)
            return
        if left and not right:
            add(state, branch, "BLOCK", f"local branch is behind remote by {left} commit(s)", local_sha=local_sha, remote_sha=remote_tip)
            return
    unique = int(git(path, "rev-list", "--count", f"origin/{state.default_branch}..{branch}"))
    if not upstream and local_sha == remote_tip:
        add(state, branch, "WAIT", "remote tip matches local branch but upstream tracking is missing", local_sha=local_sha, remote_sha=remote_tip)
        return
    if unique == 0:
        add(state, branch, "WAIT", f"no unique commits relative to origin/{state.default_branch}", local_sha=local_sha, remote_sha=remote_tip)
    elif not upstream or local_sha != remote_tip:
        add(state, branch, "PUSH", f"{unique} unique commit(s) are not fully published", local_sha=local_sha, remote_sha=remote_tip)
    else:
        add(state, branch, "PR", f"{unique} published commit(s) have no PR", local_sha=local_sha, remote_sha=remote_tip)


def inspect_repo(name: str, relative: str, fetch: bool) -> RepoState:
    path = ROOT / relative
    if not (path / ".git").exists():
        raise RuntimeError(f"missing checkout: {path}")
    if fetch:
        git(path, "fetch", "--prune", "origin")
    slug = github_repo(path)
    default = default_branch(path, slug)
    current = git(path, "branch", "--show-current") or "HEAD"
    state = RepoState(name, relative, default, current, bool(git(path, "status", "--porcelain")))
    if state.dirty:
        add(state, current, "BLOCK", "working tree has uncommitted or untracked changes")
        return state
    if current == "HEAD":
        # Detached HEAD is common in submodules; explicit refs are still inspectable.
        current = "HEAD"
    local, remote = branch_names(path)
    for branch in sorted(set(local) | set(remote)):
        inspect_branch(state, path, slug, branch, branch in local)
    return state


def apply_action(action: Action, state: RepoState, *, create_pr: bool = False,
                 pr_title_template: str = "chore: integrate {branch}",
                 pr_body: str | None = None) -> None:
    """Apply one revalidated action without checking out feature branches."""
    path = ROOT / state.path
    if state.dirty:
        raise RuntimeError("working tree is dirty")
    if action.kind == "PUSH":
        slug = github_repo(path)
        active = active_runs(slug, action.branch)
        if active:
            names = ", ".join(run_info.get("name", "unknown") for run_info in active)
            raise RuntimeError(f"active GitHub runs exist for branch; review before pushing: {names}")
        if action.remote_sha:
            git(path, "push", "origin", f"refs/heads/{action.branch}:refs/heads/{action.branch}")
            tracking = git(path, "for-each-ref", f"refs/heads/{action.branch}", "--format=%(upstream:short)")
            if not tracking:
                git(path, "branch", "--set-upstream-to", f"origin/{action.branch}", action.branch)
        else:
            git(path, "push", "-u", "origin", f"refs/heads/{action.branch}:refs/heads/{action.branch}")
    elif action.kind == "PR":
        if not create_pr:
            raise RuntimeError("PR creation requires --create-pr")
        slug = github_repo(path)
        title = pr_title_template.format(repo=state.repo, branch=action.branch)
        body = pr_body or f"Automated PR for the published `{action.branch}` branch.\n\nReview required before merge."
        run(["gh", "pr", "create", "--repo", slug, "--base", state.default_branch,
             "--head", action.branch, "--title", title, "--body", body])
    elif action.kind == "CLEANUP":
        if action.branch in PROTECTED | {state.default_branch}:
            raise RuntimeError("refusing cleanup of protected/default branch")
        if git(path, "branch", "--show-current") == action.branch:
            git(path, "switch", state.default_branch)
            git(path, "pull", "--ff-only", "origin", state.default_branch)
            if git(path, "rev-parse", state.default_branch) != git(path, "rev-parse", "origin/" + state.default_branch):
                raise RuntimeError("default branch is not synchronized after pull")
        if git(path, "rev-parse", action.branch) != action.pr_sha:
            raise RuntimeError("local SHA changed since plan; refusing cleanup")
        if action.remote_sha and remote_sha(path, action.branch) != action.pr_sha:
            raise RuntimeError("remote SHA changed since plan; refusing cleanup")
        if action.remote_sha:
            git(path, "push", f"--force-with-lease=refs/heads/{action.branch}:{action.remote_sha}",
                "origin", f":refs/heads/{action.branch}")
        git(path, "branch", "-D", action.branch)
    else:
        raise RuntimeError(f"unsupported action: {action.kind}")


def journal_key(repo: str, branch: str, kind: str, local_sha: str | None = None,
                pr_sha: str | None = None, remote_sha_value: str | None = None) -> str:
    return ":".join([repo, branch, kind, local_sha or "", pr_sha or "", remote_sha_value or ""])


def journal_successes(path: Path | None) -> set[str]:
    if path is None or not path.exists():
        return set()
    records = json.loads(path.read_text())
    return {journal_key(r["repo"], r["branch"], r["kind"], r.get("local_sha"),
                           r.get("pr_sha"), r.get("remote_sha"))
            for r in records if r.get("status") == "success"}


def confirm(prompt: str) -> bool:
    try:
        return input(prompt).strip().lower() in {"y", "yes"}
    except EOFError:
        print()
        return False


def write_journal(path: Path | None, record: dict[str, Any]) -> None:
    if path is None:
        return
    existing = []
    if path.exists():
        existing = json.loads(path.read_text())
    record = {**record, "timestamp": datetime.now(timezone.utc).isoformat()}
    existing.append(record)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(existing, indent=2) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="apply PUSH/CLEANUP actions")
    parser.add_argument("--apply-all", action="store_true", help="apply actions for all branches; implies --apply")
    parser.add_argument("--fetch", action="store_true", help="fetch and prune before planning")
    parser.add_argument("--json", action="store_true", help="emit JSON plan")
    parser.add_argument("--audit-protection", action="store_true", help="report default-branch protection")
    parser.add_argument("--only", action="append", choices=sorted(REPOSITORIES), help="limit to selected repo(s)")
    parser.add_argument("--keep-network-env", action="store_true", help="do not strip proxy/SSL environment variables")
    parser.add_argument("--create-pr", action="store_true", help="allow PR creation for published branches")
    parser.add_argument("--journal", type=Path, help="append applied actions to a JSON journal")
    parser.add_argument("--resume", type=Path, help="skip actions already successful in this journal")
    parser.add_argument("--yes", action="store_true", help="skip interactive mutation confirmations")
    parser.add_argument("--pr-title-template", default="chore: integrate {branch}",
                        help="PR title template; supports {repo} and {branch}")
    parser.add_argument("--pr-body", help="PR body used by --create-pr")
    args = parser.parse_args()
    global STRIP_NETWORK_ENV
    STRIP_NETWORK_ENV = not args.keep_network_env
    selected = {name: path for name, path in REPOSITORIES.items() if not args.only or name in args.only}
    states: dict[str, RepoState] = {}
    fetch = args.fetch or args.apply or args.apply_all
    try:
        for name, relative in selected.items():
            states[name] = inspect_repo(name, relative, fetch)
    except (RuntimeError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2
    successes = journal_successes(args.resume or args.journal)
    if args.json:
        payload = {"repositories": [asdict(s) for s in states.values()]}
        if args.audit_protection:
            payload["protection"] = {
                state.repo: protection_report(github_repo(ROOT / state.path), state.default_branch)
                for state in states.values()
            }
        print(json.dumps(payload, indent=2))
    else:
        for state in states.values():
            print(f"{state.repo}: current={state.current} default={state.default_branch} dirty={state.dirty}")
            if args.audit_protection:
                report = protection_report(github_repo(ROOT / state.path), state.default_branch)
                print(f"  protection: {json.dumps(report, sort_keys=True)}")
            for action in state.actions:
                print(f"  {action.branch}: {action.kind} — {action.reason}")
    if not (args.apply or args.apply_all):
        return 0
    for state in states.values():
        if state.dirty:
            print(f"BLOCK {state.repo}: dirty working tree; no actions applied")
            continue
        for action in state.actions:
            if action.kind not in {"PUSH", "PR", "CLEANUP"}:
                print(f"SKIP {state.repo}/{action.branch}: {action.kind} is plan-only")
                continue
            if action.kind == "PR" and not args.create_pr:
                print(f"SKIP {state.repo}/{action.branch}: PR creation disabled; use --create-pr")
                continue
            if not args.apply_all and action.branch != state.current:
                continue
            key = journal_key(state.repo, action.branch, action.kind, action.local_sha, action.pr_sha, action.remote_sha)
            if key in successes:
                print(f"SKIP {state.repo}/{action.branch}: {action.kind} already succeeded in journal")
                continue
            if not args.yes:
                if not confirm(f"Apply {action.kind} for {state.repo}/{action.branch}? [y/N] "):
                    print(f"SKIP {state.repo}/{action.branch}: confirmation declined")
                    continue
            try:
                fresh = inspect_repo(state.repo, state.path, True)
                fresh_action = next((a for a in fresh.actions if a.branch == action.branch and a.kind == action.kind), None)
                if not fresh_action or asdict(fresh_action) != asdict(action):
                    raise RuntimeError("state changed since plan; re-run in plan mode")
                apply_action(fresh_action, fresh, create_pr=args.create_pr,
                             pr_title_template=args.pr_title_template, pr_body=args.pr_body)
                record = {"repo": state.repo, "branch": action.branch, "kind": action.kind,
                          "status": "success", "local_sha": fresh_action.local_sha,
                          "pr_sha": fresh_action.pr_sha, "remote_sha": fresh_action.remote_sha}
                write_journal(args.journal, record)
                print(f"OK {state.repo}/{action.branch}: {action.kind}")
            except (RuntimeError, ValueError, json.JSONDecodeError) as error:
                write_journal(args.journal, {"repo": state.repo, "branch": action.branch, "kind": action.kind,
                                             "status": "failed", "error": str(error),
                                             "local_sha": action.local_sha, "pr_sha": action.pr_sha,
                                             "remote_sha": action.remote_sha})
                print(f"ERROR applying {state.repo}/{action.branch}: {error}", file=sys.stderr)
                print("Stopped at first mutation error; earlier actions remain applied.", file=sys.stderr)
                return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
