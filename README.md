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
| [`pf-db`](pf-db/README.md) | Single source of truth for the PostgreSQL schema (DDL + Alembic migrations + seeds). No application code. | [README](pf-db/README.md) · [AGENTS](pf-db/AGENTS.md) |
| [`pf-rates`](pf-rates/README.md) | FastAPI microservice for financial reference data: exchange rates (USD/EUR), indices (UF/UTM/CPI), income tax brackets. | [README](pf-rates/README.md) · [AGENTS](pf-rates/AGENTS.md) |
| [`pf-payroll`](pf-payroll/README.md) | FastAPI microservice for Chilean payroll: payslip import, AFP/health/unemployment insurance/tax computation, PDF reports, dashboard and CLI. | [README](pf-payroll/README.md) · [AGENTS](pf-payroll/AGENTS.md) |
| [`pf-common`](pf-common/README.md) | Shared infrastructure (Make targets, scripts) consumed by `pf-rates` and `pf-payroll`. **Not** used by `pf-db`. | [README](pf-common/README.md) |

## Repository structure

This root directory is itself a git repo (`pf-base`) that tracks only ecosystem-level
files — this `README.md`, `AGENTS.md`, and `pf-architecture/`. Each subproject folder
(`pf-db`, `pf-rates`, `pf-payroll`, `pf-common`) is a **separate, independent git repo**
with its own remote and commit history; root's `.gitignore` excludes them on purpose so
they never show up as untracked files here. Clone, pull, and push each subproject from
inside its own folder — there is no submodule wiring between them.

## How they relate

```
pf-rates  ──┐
            ├── PostgreSQL (schema/migrations in pf-db)
pf-payroll ─┘

pf-rates, pf-payroll ──> share Makefiles/scripts from pf-common
```

- `pf-db` owns the schema; `pf-rates` and `pf-payroll` each keep their own ORM
  models/repositories but connect to the same Postgres instance.
- `pf-payroll` consumes `pf-rates` over HTTP for exchange rates and tax brackets.
- `pf-common` provides reusable `make install/test/lint/check/...` targets for FastAPI services.

## Architecture diagram

[`pf-architecture/diagram.html`](pf-architecture/diagram.html) is a self-contained, interactive diagram
(generated with [Archify](https://github.com/tt-a1i/archify)) of how the four subprojects
fit together at runtime: the two FastAPI services, the shared PostgreSQL instance, the
schema owner, and the shared build tooling. Open it in a browser for pan/zoom, theme
toggle, and relationship tracing — it's the visual companion to the "How they relate"
section above, not a replacement for the per-subproject docs.

The diagram source (`pf-architecture/diagram.json`) and the regeneration script
(`pf-architecture/generate.sh`) live next to the output, so it can be rebuilt after any
topology change instead of hand-edited:

```bash
cd pf-architecture
./generate.sh --open
```

## Where to start

1. Bring up the database: follow the quick start in [`pf-db`](pf-db/docs/getting-started.md).
2. Bring up `pf-rates`: [`pf-rates/docs/getting-started.md`](pf-rates/docs/getting-started.md).
3. Bring up `pf-payroll`: [`pf-payroll/docs/getting-started.md`](pf-payroll/docs/getting-started.md).

## Scripts

Utility scripts that operate across the whole ecosystem live in [`scripts/`](scripts/),
separate from each subproject's own `scripts/` (e.g. `pf-common/scripts/`, which holds
service-level tooling instead).

| Script | Purpose |
| --- | --- |
| [`scripts/find-md.sh`](scripts/find-md.sh) | Recursively lists `*.md` files, skipping noise dirs (`.venv`, `.git`, `node_modules`, etc.). Supports `-d DIR` to scope the search and `-i FILE1,FILE2` to exclude filenames. Run `./scripts/find-md.sh --help` for details. |

## Global conventions

Fully detailed in each subproject's `AGENTS.md`, in short:

- Code/docs language: English (except official Chilean regulatory terms).
- `Decimal`/`NUMERIC`, never `float`/`FLOAT` for amounts and rates.
- Hexagonal architecture (ports and adapters) in `pf-rates` and `pf-payroll`.
- SemVer + Conventional Commits; no agent commits/pushes/opens a PR without explicit instruction.
