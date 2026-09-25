# pf — Personal Finance Ecosystem (Chile)

Folder-monorepo containing the microservices and utilities of the PF ecosystem: Chilean
payroll/tax calculation and financial reference data (exchange rates, economic indices,
income tax brackets).

> This README is a lightweight index. Each subproject has its own `README.md` (quick
> start + docs) and `AGENTS.md` (architecture, style, design principles) — read those,
> not this one, for anything specific.

## Subprojects

| Folder | What it is | Docs |
| --- | --- | --- |
| [`pf-db`](modules/pf-db/README.md) | Single source of truth for the PostgreSQL schema (DDL + Alembic migrations + seeds). No application code. | [README](modules/pf-db/README.md) · [AGENTS](modules/pf-db/AGENTS.md) |
| [`pf-rates`](modules/pf-rates/README.md) | FastAPI microservice for financial reference data: exchange rates (USD/EUR), indices (UF/UTM/CPI), income tax brackets. | [README](modules/pf-rates/README.md) · [AGENTS](modules/pf-rates/AGENTS.md) |
| [`pf-payroll`](modules/pf-payroll/README.md) | FastAPI microservice for Chilean payroll: payslip import, AFP/health/unemployment insurance/tax computation, PDF reports, dashboard and CLI. | [README](modules/pf-payroll/README.md) · [AGENTS](modules/pf-payroll/AGENTS.md) |
| [`pf-common`](modules/pf-common/README.md) | Shared infrastructure (Make targets, scripts) consumed by `pf-rates` and `pf-payroll`. **Not** used by `pf-db`. | [README](modules/pf-common/README.md) |
| [`pf-sheets`](modules/pf-sheets/README.md) | Google Apps Script (bound to a Sheet) that syncs `pf-rates` exchange rates into a spreadsheet. Versioned in Git, deployed via `clasp`. | [README](modules/pf-sheets/README.md) · [AGENTS](modules/pf-sheets/AGENTS.md) |

## Repository structure

This root directory is itself a git repo (`pf-base`) that tracks only ecosystem-level
files — this `README.md`, `AGENTS.md`, and `architecture/`. Each subproject folder
(`pf-db`, `pf-rates`, `pf-payroll`, `pf-common`, `pf-sheets`) lives under `modules/` and
is a **separate, independent git repo**
with its own remote and commit history; root's `.gitignore` excludes the whole
`modules/` folder on purpose so they never show up as untracked files here. Clone,
pull, and push each subproject from inside its own folder (e.g. `modules/pf-rates`) —
there is no submodule wiring between them.

## How they relate

```
pf-rates  ──┐
            ├── PostgreSQL (schema/migrations in pf-db)
pf-payroll ─┘

pf-rates, pf-payroll ──> share Makefiles/scripts from pf-common

pf-sheets ──> HTTP: triggers pf-rates export ──> Google Sheets/Drive (Apps Script APIs)
```

- `pf-db` owns the schema; `pf-rates` and `pf-payroll` each keep their own ORM
  models/repositories but connect to the same Postgres instance.
- `pf-payroll` consumes `pf-rates` over HTTP for exchange rates and tax brackets.
- `pf-common` provides reusable `make install/test/lint/check/...` targets for FastAPI services.
- `pf-sheets` is a Google Apps Script macro: it triggers a `pf-rates` export over HTTP,
  then reads the resulting CSV from Google Drive and upserts it into a Sheet.

## Architecture diagram

[`architecture/index.html`](architecture/index.html) links to all of them; start there.
[`architecture/base.html`](architecture/base.html) is the self-contained, interactive
ecosystem diagram (generated with [Archify](https://github.com/tt-a1i/archify)) of how the
five subprojects fit together at runtime: the two FastAPI services, the shared PostgreSQL
instance, the schema owner, the shared build tooling, and the Apps Script integration. Open
it in a browser for pan/zoom, theme toggle, and relationship tracing — it's the visual
companion to the "How they relate" section above, not a replacement for the per-subproject
docs. Each subproject also has its own detailed diagram (internal layers for
`pf-payroll`/`pf-rates`/`pf-sheets`, table ownership for `pf-db`) — see
[`architecture/README.md`](architecture/README.md) for the full breakdown.

The diagram source (`architecture/base.json`) and the regeneration script
(`architecture/generate.sh`) live next to the output, so it can be rebuilt after any
topology change instead of hand-edited:

```bash
cd architecture
./generate.sh --open
```

## Postman collection

[`postman/pf-ecosystem.postman_collection.json`](postman/pf-ecosystem.postman_collection.json)
is a single Postman collection covering every HTTP surface in the ecosystem
(`pf-rates`, `pf-payroll`, `pf-sheets`'s Web App — `pf-db` has no HTTP API). It's plain
JSON, edited directly like any other file here, and pushed to a real Postman workspace
automatically on every push to `main` via `.github/workflows/sync-postman.yml`. See
[`postman/README.md`](postman/README.md) for one-time setup and how the sync works.

## Where to start

1. Bring up the database: follow the quick start in [`pf-db`](modules/pf-db/docs/getting-started.md).
2. Bring up `pf-rates`: [`pf-rates/docs/getting-started.md`](modules/pf-rates/docs/getting-started.md).
3. Bring up `pf-payroll`: [`pf-payroll/docs/getting-started.md`](modules/pf-payroll/docs/getting-started.md).
4. Set up `pf-sheets`: [`pf-sheets/docs/getting-started.md`](modules/pf-sheets/docs/getting-started.md).

## Scripts

Utility scripts that operate across the whole ecosystem live in [`scripts/`](scripts/),
separate from each subproject's own `scripts/` (e.g. `pf-common/scripts/`, which holds
service-level tooling instead).

| Script | Purpose |
| --- | --- |
| [`scripts/find-docs.sh`](scripts/find-docs.sh) | Recursively lists `*.md`, `*.txt`, and `*.sh` files, skipping noise dirs (`.venv`, `.git`, `node_modules`, etc.). Supports `-d DIR` to scope the search and `-i FILE1,FILE2` to exclude filenames. Run `./scripts/find-docs.sh --help` for details. |

## Global conventions

Fully detailed in each subproject's `AGENTS.md`, in short:

- Code/docs language: English (except official Chilean regulatory terms).
- `Decimal`/`NUMERIC`, never `float`/`FLOAT` for amounts and rates.
- Hexagonal architecture (ports and adapters) in `pf-rates` and `pf-payroll`.
- SemVer + Conventional Commits.
- **Cloud cost is always the priority for cloud decisions**: cheapest viable option first
  (scale-to-zero, free/cheaper equivalents, on-demand over always-on). See
  [`AGENTS.md`](AGENTS.md#rules-common-to-the-3-servicesschema-repo) and each subproject's
  `docs/deployment.md` (pf-rates/pf-payroll) or `docs/ci.md` (pf-db).
