# Scripts

Repository utilities are grouped by responsibility:

- [`quality/`](quality/README.md) — documentation, language, search, and word tools;
- [`git/`](git/README.md) — ecosystem branch/PR orchestration and recovery;
- [`local/`](local/README.md) — local service-stack helpers;
- [`github/`](github/README.md) — GitHub connectivity helpers;
- [`neon/`](neon/README.md) — Neon validation helpers and runtime templates;
- `cloudshell/` — runtime-only Cloud Shell scripts and archives.

Run scripts from the repository root unless their README says otherwise.

## Complete local Postman run

[`run-all-postman-tests.sh`](run-all-postman-tests.sh) starts the local PF stack via
`local/pf-services.sh restart`, restores `modules/pf-db/secrets/neon_dump.sql`
when present (otherwise skips that step), materializes only temporary credentials
and synthetic file fixtures, runs coverage, error contracts, the read-only smoke subset, the complete local
Newman collection (including mutations), payroll file contracts, and the synthetic
mutating integration workflow. The external `pf-sheets` folder is excluded because
it has no local service. It resets the local database and stops services on exit.

The script is intentionally LOCAL-only. It loads the local keys automatically from
`secrets/pf-runtime-api-keys.env` using `LOCAL_PF_RATES_API_KEY` and
`LOCAL_PF_PAYROLL_API_KEY`. Explicit `PF_RATES_API_KEY` and `PF_INCOME_API_KEY`
environment variables take precedence when provided:

```bash
scripts/run-all-postman-tests.sh
```

The secrets file is ignored and its values are never printed or committed.

The local collection run is a deliberate Run All and includes mutations, refreshes,
imports, deletes, and asynchronous operations. If Newman is not already available,
the script installs it automatically under a temporary directory using `npm`; no
global installation is required. It only needs `npm`/Node.js when Newman is
missing. The script never targets GCP, Neon,
production, or the external `pf-sheets` Web App. JUnit reports are written to
`generated/postman-local/`.

## Workspace synchronization

[`update-workspace.py`](update-workspace.py) discovers every nested local Git
checkout, synchronizes the VS Code workspace file, and refreshes the local module index:

```bash
python3 scripts/update-workspace.py
```

Use `--check` in validation or CI to fail when `pf.code-workspace` is stale:

```bash
python3 scripts/update-workspace.py --check
```

The script also generates the Git-ignored local file `modules/INDEX.json` with metadata for repositories
found only under `modules/`. It never includes `improvements`, `postman`, or any
other checkout outside that directory. Repository paths are always discovered
directly from the local checkout layout.
