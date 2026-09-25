# AGENTS.md — pf (ecosystem root)

Index for AI agents working in this workspace. This file **does not go deep**: each
subproject is its own git repo with its own authoritative `AGENTS.md`. Read that before
touching code there.

## Structure

| Subproject | AGENTS.md | Role |
| --- | --- | --- |
| [`pf-db`](modules/pf-db/AGENTS.md) | DDL + Alembic migrations. No application code, no autogenerate. | Schema owner |
| [`pf-rates`](modules/pf-rates/AGENTS.md) | FastAPI microservice, hexagonal architecture. | Financial reference data |
| [`pf-payroll`](modules/pf-payroll/AGENTS.md) | FastAPI microservice, hexagonal architecture. | Payroll/tax |
| [`pf-common`](modules/pf-common/README.md) | No own AGENTS.md; just a README with shared Make targets. | Shared infra |
| [`pf-sheets`](modules/pf-sheets/AGENTS.md) | Google Apps Script bound to a Sheet (JavaScript, not Python — see its own `AGENTS.md`, it does not follow the Python rules below). Deployed via `clasp`. | Sheets/Drive integration |

This root directory (`pf/`) **is its own git repo** (`pf-base`, remote on GitHub) — it
tracks only ecosystem-level files: this `AGENTS.md`, `README.md`, `architecture/`,
and `.gitignore`. The five subprojects (`pf-db`, `pf-rates`, `pf-payroll`, `pf-common`,
`pf-sheets`) live under `modules/` and remain **independent git repos** with their own
`.git`, remote, and history — root's
`.gitignore` deliberately excludes the whole `modules/` folder so `git status` here
stays clean and never shows them as untracked. To commit/push inside a subproject, `cd`
into it first; committing from root only ever touches ecosystem-level docs.

**Never autonomously commit, push branches, create issues, or open PRs — requires
explicit user command.** This applies everywhere: the root repo and every subproject
repo, no exceptions.

**Post-push monitoring:** after pushing, monitor the pipeline in GitHub Actions
(`gh run watch` or the Actions tab). It will eventually reach a manual approval stage —
never autonomously approve; requires explicit user command. Deploy pipelines queue
rather than auto-cancel superseded runs (`cancel-in-progress: false`, deliberate — see
`pf-common/.github/workflows/deploy-reusable.yml`), so check `gh run list` for older
runs of the same workflow already stuck at that stage and cancel them with
`gh run cancel <run-id>` so only the current run remains pending.

## Rules common to the 3 services/schema repo

(Full detail in each one's `AGENTS.md` — this is just the summary so you don't waste
time re-reading the same thing three times. **`pf-sheets` is out of scope for this
section** — it's a JavaScript/Apps Script repo, not Python, and follows its own
conventions documented in `pf-sheets/AGENTS.md` instead.)

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
- **Git/versioning:** SemVer + Conventional Commits in English (commit/push policy above
  applies here too).
- **Cross-repo coordination:** schema changes are coordinated in `pf-db`; `pf-rates` and
  `pf-payroll` never edit their ORM models without a corresponding migration in `pf-db`.
- **Cloud cost optimization — always the priority:** any decision touching cloud
  infrastructure (compute, storage, scanning, networking, managed services) must default
  to the cheapest viable option before anything else. Scale-to-zero, free/cheaper
  equivalents over paid add-ons, on-demand jobs over always-on services, no
  over-provisioning "just in case". Existing examples already baked into pf-rates and
  pf-payroll: `--min-instances=0`, Trivy (free) instead of paid Artifact Registry
  scanning, external DB option to avoid Cloud SQL when not needed. Any new infra
  proposal must state its cost impact and the cheaper alternatives considered.

## Where to go deeper

Don't repeat context here — go straight to the relevant doc:

- Service architecture/style → the subproject's `AGENTS.md`.
- How to run something → the subproject's `docs/getting-started.md`.
- CI/CD → `docs/deployment.md` (pf-rates, pf-payroll) or `docs/ci.md` (pf-db).
- Schema/tables → `modules/pf-db/docs/tables.md` and `modules/pf-db/docs/migrations.md`.
- Apps Script/Sheets integration → `modules/pf-sheets/AGENTS.md` and
  `modules/pf-sheets/docs/ci.md`.
