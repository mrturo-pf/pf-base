# AGENTS.md — pf (ecosystem root)

Index for AI agents working in this workspace. This file **does not go deep**: each
subproject is its own git repo with its own authoritative `AGENTS.md`. Read that before
touching code there.

## Structure

| Subproject | AGENTS.md | Role |
| --- | --- | --- |
| [`pf-db`](pf-db/AGENTS.md) | DDL + Alembic migrations. No application code, no autogenerate. | Schema owner |
| [`pf-rates`](pf-rates/AGENTS.md) | FastAPI microservice, hexagonal architecture. | Financial reference data |
| [`pf-payroll`](pf-payroll/AGENTS.md) | FastAPI microservice, hexagonal architecture. | Payroll/tax |
| [`pf-common`](pf-common/README.md) | No own AGENTS.md; just a README with shared Make targets. | Shared infra |

This root directory (`pf/`) **is not a git repo** — do not run `git commit`/`push` here;
each subfolder has its own `.git`.

## Rules common to the 3 services/schema repo

(Full detail in each one's `AGENTS.md` — this is just the summary so you don't waste
time re-reading the same thing three times.)

- **Language:** all code, identifiers, comments, and docstrings in English. Exception:
  official Chilean regulatory terms/SQL literals/seed data, only when translating would
  change the meaning.
- **Financial precision:** `Decimal` in Python, `NUMERIC` in Postgres. Never `float`/`FLOAT`.
- **Style:** ruff with `extend-select = ["D", "E", "W", "UP"]`, `pep257` convention.
- **Architecture (pf-rates, pf-payroll):** hexagonal — `interfaces → application → domain`,
  `infrastructure → application`. `domain/` has no I/O or external dependencies. Ports are
  `typing.Protocol`. DTOs are the only thing crossing layer boundaries.
- **Design:** DRY, SOLID, Clean Code, DDD. No god objects. `assert` is forbidden for
  production validation — raise from `application/errors.py` instead. No silent fallbacks.
- **pf-db specific:** idempotent migrations (`IF NOT EXISTS`, `ON CONFLICT`), always a real
  `downgrade()`, hand-written SQL (no autogenerate).
- **Git/versioning:** SemVer + Conventional Commits in English. No agent autonomously
  commits, pushes, creates issues, or opens PRs — requires explicit user instruction.
- **Cross-repo coordination:** schema changes are coordinated in `pf-db`; `pf-rates` and
  `pf-payroll` never edit their ORM models without a corresponding migration in `pf-db`.

## Where to go deeper

Don't repeat context here — go straight to the relevant doc:

- Service architecture/style → the subproject's `AGENTS.md`.
- How to run something → the subproject's `docs/getting-started.md`.
- CI/CD → `docs/deployment.md` (pf-rates, pf-payroll) or `docs/ci.md` (pf-db).
- Schema/tables → `pf-db/docs/tables.md` and `pf-db/docs/migrations.md`.
