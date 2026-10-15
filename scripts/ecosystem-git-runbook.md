# Ecosystem Git runbook

`scripts/ecosystem-git.py` plans branch publication, PR creation, and cleanup.
It does not perform automatic rollback or merge production PRs.

## Safe workflow

```bash
python3 scripts/ecosystem-git.py --fetch --json > /tmp/pf-git-plan.json
python3 scripts/ecosystem-git.py --fetch --apply-all \
  --create-pr --journal /tmp/pf-git-actions.json
```

Review every PR before merging. Use `--yes` only from a controlled, non-interactive
runner after reviewing the plan.

## Recovery by operation

### A push was made to the wrong branch

Do not force-push over it. Inspect the remote SHA and create a recovery branch:

```bash
git fetch origin
git switch -c recovery/<short-name> <remote-sha>
```

Open a PR from the recovery branch or close it after the owner confirms the commit
is disposable.

### A local branch was deleted

Use the recorded SHA or reflog:

```bash
git reflog --all
git branch recovery/<short-name> <sha>
```

Do not run cleanup again until the recovery branch is verified.

### A remote branch was deleted

Recreate it only from a known SHA:

```bash
git push origin <sha>:refs/heads/<branch>
```

Confirm that no replacement branch or PR has reused the name first.

### A PR was merged but the release failed

Do not revert automatically. First inspect the release workflow, deployed revision,
smoke-test evidence, and database migration state. Then choose explicitly between:

- a forward fix through a new PR;
- a service-specific rollback to a known revision;
- a database-specific recovery plan.

### A database migration failed

Stop dependent deployments. Inspect the migration job and database state before
retrying. Do not run a generic Git revert as a database rollback; schema and data
changes may require a dedicated forward migration or an approved restore procedure.

## Journal

The journal records successful and failed mutations:

```bash
python3 scripts/ecosystem-git.py --apply-all \
  --journal /tmp/pf-git-actions.json
```

Resume only after reviewing the partial run:

```bash
python3 scripts/ecosystem-git.py --apply-all \
  --resume /tmp/pf-git-actions.json \
  --journal /tmp/pf-git-actions.json
```

The journal is local operational evidence and must not contain secrets.
