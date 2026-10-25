# Scripts

Repository utilities are grouped by responsibility:

- [`quality/`](quality/README.md) — documentation, language, search, and word tools;
- [`git/`](git/README.md) — ecosystem branch/PR orchestration and recovery;
- [`local/`](local/README.md) — local service-stack helpers;
- [`github/`](github/README.md) — GitHub connectivity helpers;
- [`neon/`](neon/README.md) — Neon validation helpers and runtime templates;
- `cloudshell/` — runtime-only Cloud Shell scripts and archives.

Run scripts from the repository root unless their README says otherwise.

## Workspace synchronization

[`update-workspace.py`](update-workspace.py) discovers every nested local Git
checkout and synchronizes only the VS Code workspace file:

```bash
python3 scripts/update-workspace.py
```

Use `--check` in validation or CI to fail when `pf.code-workspace` is stale:

```bash
python3 scripts/update-workspace.py --check
```

The script does not create or read a repository index. The workspace file is the
single generated artifact and repository paths are discovered directly from the
local checkout layout.
