# AGENTS.md — PF ecosystem

This file is the **ecosystem coordination guide** for the PF (Personal Finances)
workspace. It defines repository boundaries, ownership, cross-repository workflows,
shared safety rules, and integration contracts.

It does **not** define detailed implementation rules for individual repositories.
Before changing a subrepository, read that repository's own `AGENTS.md`. The local
`AGENTS.md` is authoritative for implementation, testing, and repository-specific
operations, provided it does not violate ecosystem-wide boundaries or safety rules.

## Purpose and document boundaries

This root file answers: **How is the ecosystem organized, and how do repositories
coordinate with one another?** It owns only rules that must be consistent across two
or more repositories.

A subrepository's `AGENTS.md` answers: **How do I implement, test, document, and
operate this repository correctly?** It owns the repository's architecture, language
and framework conventions, directory structure, local commands, test strategy,
deployment details, and repository-specific invariants.

Keep this boundary explicit:

- Add a rule to the **root** only when it describes ownership, cross-repository
  coordination, shared safety, or a contract consumed by multiple repositories.
- Add a rule to a **subrepository** when it describes implementation, testing,
  tooling, deployment, or operations specific to that repository.
- Do not copy a local technical rule into the root for convenience. Link to the local
  `AGENTS.md` instead.
- Do not put ecosystem-wide ownership or compatibility rules only in a local file.
  Document them here and link to the affected local instructions.
- When a rule appears to apply to both levels, keep the root rule short and generic;
  put the actionable details in the local repository's `AGENTS.md`.

Before editing any `AGENTS.md`, classify the change as **ecosystem coordination** or
**repository implementation guidance**. That classification determines the file to
change and prevents the root from becoming a duplicate implementation manual.

## Repository map

| Repository | Responsibility | Local instructions |
| --- | --- | --- |
| [`pf-db`](modules/pf-db) | PostgreSQL schema, DDL, seeds, and Alembic migrations | [`modules/pf-db/AGENTS.md`](modules/pf-db/AGENTS.md) |
| [`pf-rates`](modules/pf-rates) | Financial reference data and HTTP API | [`modules/pf-rates/AGENTS.md`](modules/pf-rates/AGENTS.md) |
| [`pf-payroll`](modules/pf-payroll) | Payroll, tax, and employer domain plus HTTP API | [`modules/pf-payroll/AGENTS.md`](modules/pf-payroll/AGENTS.md) |
| [`pf-sheets`](modules/pf-sheets) | Google Apps Script, Sheets integration, and Web App | [`modules/pf-sheets/AGENTS.md`](modules/pf-sheets/AGENTS.md) |
| `pf-common` | Shared infrastructure and Make targets; no local `AGENTS.md` | [`modules/pf-common/README.md`](modules/pf-common/README.md) |

The root repository (`pf-base`) contains ecosystem-level documentation, architecture
descriptions, Postman assets, and coordination rules. Each directory under
`modules/` is an independent Git repository with its own history, remote, and
working tree. Run Git commands from the repository they affect.

## Ownership boundaries

| Responsibility | Owner | Consumers |
| --- | --- | --- |
| PostgreSQL schema, DDL, migrations, and schema seeds | `pf-db` | `pf-rates`, `pf-payroll` |
| Financial reference-data domain and service behavior | `pf-rates` | `pf-payroll`, `pf-sheets` |
| Payroll and tax domain and service behavior | `pf-payroll` | ecosystem clients |
| Spreadsheet synchronization and Apps Script Web App | `pf-sheets` | Google Sheets and service clients |
| Shared development/build infrastructure | `pf-common` | ecosystem repositories |

Schema ownership and domain ownership are different responsibilities. `pf-db` owns
how shared database objects are defined and migrated. A service owns the business
data and behavior for its domain, including which service writes its tables.
Services may read shared data according to the owning repository's documented schema
and integration contracts. Only the service that owns a domain should write its domain
tables; do not change another repository's implementation as a local workaround.

## Cross-repository change protocol

Before changing code, identify every repository affected and read each affected
repository's local `AGENTS.md`.

### Database and schema changes

1. Define the required schema behavior and compatibility checks.
2. Implement the DDL and migration in `pf-db`, which is the schema owner.
3. Coordinate matching ORM/model and repository changes in consuming services.
4. Apply and validate the migration before deploying consumers that require it.
5. Update relevant database documentation and integration fixtures.

Services must not edit ORM models for a schema change without a corresponding,
reviewed migration in `pf-db`.

### HTTP and integration contract changes

1. Update the repository that owns the contract.
2. Update that repository's `docs/api.md` in the same change.
3. Update the shared Postman collection and environments when applicable.
4. Update all known consumers and validate the complete workflow.

The ecosystem's HTTP surface includes FastAPI endpoints from `pf-rates` and
`pf-payroll`, and Google Apps Script Web App endpoints from `pf-sheets`. These are
HTTP contracts, but they do not share the same runtime, framework, or deployment
model.

### Deployment and infrastructure changes

Check dependency order and rollback behavior across repositories. Database migrations
must be applied before a service receives traffic. Prefer the cheapest viable cloud
architecture: scale-to-zero, on-demand jobs, free tooling, and no unnecessary
provisioning. Any infrastructure proposal must state its cost impact and the cheaper
alternatives considered.

## Shared rules

- Do not autonomously commit, push, create branches, open pull requests, or create
  issues. These actions require an explicit user command.
- Use SemVer and Conventional Commits in English.
- Keep code, identifiers, comments, and documentation in English, except official
  Chilean regulatory terms, source literals, and seed data when translation would
  change their meaning.
- Do not add or expand product-facing CLI commands without explicit user approval.
  Existing development, deployment, and automation tools such as `make`, `clasp`, and
  repository scripts may be used.
- Never commit secrets, credentials, or sensitive personal/health data.
- Do not introduce silent fallbacks or bypass an owning repository's boundary.
- Preserve the financial-precision contract: Python monetary/rate values use
  `Decimal`, and PostgreSQL monetary/rate columns use `NUMERIC`.
- Behavioral changes must follow the applicable test policy in the local repository.
  Cross-repository changes should begin with an observable contract or acceptance test
  and must validate compatibility at the integration boundary.
- Documentation-only, formatting-only, mechanical refactors, and generated files do
  not require artificial tests, but applicable validation still has to run.

## Documentation contracts

These files describe public or cross-repository behavior and must stay synchronized
with implementation:

- `modules/pf-rates/docs/api.md`
- `modules/pf-payroll/docs/api.md`
- `modules/pf-sheets/docs/api.md`
- `postman/pf-ecosystem.postman_collection.json`
- `postman/pf-ecosystem.postman_environment.local.json`
- `postman/pf-ecosystem.postman_environment.gcp.json`

If an endpoint path, request/response shape, authentication rule, or error contract
changes, update the owning repository's API documentation and the relevant Postman
assets in the same change. When documentation and implementation disagree, verify the
actual route definitions, `GET /openapi.json`, or `pf-sheets/src/interfaces/webapp.js`
before deciding which one is stale.

## GitHub and network operations

Before any interaction with GitHub through `gh`, including read-only commands, run
`unset-proxies` or its underlying script:

```bash
source "$HOME/Documents/scripts/unset_proxies.sh"
```

Before pushing, inspect the target repository's active workflow runs and cancel only
older active runs for the same workflow, branch, and repository. Verify cancellation
before pushing, then monitor the new run by its exact SHA or run ID. Manual deployment
approval always requires explicit user authorization. If GitHub is unreachable, retry
a couple of times and stop; never assume an operation succeeded.

## Working in this workspace

Use this sequence:

1. Identify the repository or repositories affected.
2. Read the relevant local `AGENTS.md` files.
3. Inspect the existing implementation, tests, and documentation.
4. For cross-repository work, define the contract and ownership before editing.
5. Make the smallest cohesive change in each affected repository.
6. Run each repository's documented validation commands.
7. Review each repository's diff and status independently.
8. Commit only when explicitly requested; never push unless explicitly requested.

For detailed architecture, development, testing, database, and deployment rules, use
the local documentation referenced by the relevant subrepository's `AGENTS.md`.
