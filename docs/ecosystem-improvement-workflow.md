# PF Ecosystem Improvement Workflow

This document defines the standard workflow for researching, designing,
implementing, validating, and releasing improvements across the PF ecosystem.
It consolidates the conventions proven useful in the existing investigation,
brief, recommendation, and living-plan documents.

The workflow applies to changes touching one or more of `pf-base`, `pf-db`,
`pf-rates`, `pf-payroll`, `pf-sheets`, or `pf-common`.

## Principles

1. **Evidence before design.** Do not design against imagined routes, schemas,
   consumers, or deployment behavior. Inspect the actual repositories, OpenAPI,
   database ownership, workflows, and versioned consumers.
2. **Decisions are separate from execution.** A recommendation records what
   should be built and why. A plan records how the approved work is executed.
3. **The plan is the living implementation record.** Findings, corrections,
   deviations, test results, and rollout observations belong in the plan's
   dated change log. The recommendation changes only when the design decision
   itself changes.
4. **Reality outranks the proposal.** If implementation contradicts the design,
   stop, document the discrepancy, decide whether to update the design, and
   continue only after the resulting scope is explicit.
5. **Cross-repository ownership is explicit.** Schema changes belong to
   `pf-db`; service consumers follow the migration. `pf-sheets` is treated as a
   separate JavaScript/Apps Script system, not as a Python service.
6. **The public contract is synchronized in the same change.** HTTP changes
   require route/OpenAPI verification, service `docs/api.md` updates, and the
   root Postman collection update when applicable. For Postman request selection,
   operational examples, and negative-test boundaries, follow
   [`postman/README.md`](../postman/README.md).
7. **Synthetic data only.** Investigations and tests must not introduce real
   payslips, RUTs, salaries, health information, or credentials into git.
8. **No autonomous release authority.** Commit, push, deployment approval, and
   destructive production actions require explicit user authorization.

Repository-specific rules are authoritative in the root and module
`AGENTS.md`/`README.md` files. This document defines lifecycle gates and
artifact responsibilities; it does not override or duplicate those rules. In
particular, Git/CLI/network, code style, language, financial precision, cloud
cost, and security policies must be read from the owning repository's current
instructions.

## Change sizing

Not every change deserves the full ceremony. Classify the change before creating
artifacts:

| Level | Typical example | Minimum artifacts and gates |
| --- | --- | --- |
| S | Isolated bug fix or one-file behavior correction with no public contract, schema, or cross-repo impact | Normal repository tests, commit description, and the owning repository's quality gates |
| M | Feature contained in one repository with no schema change, public API change, deletion, or cross-repo dependency | Recommendation plus implementation checklist; add a brief when the problem or acceptance criteria need clarification |
| L | Database/schema change, public API or Apps Script contract, multiple repositories, deletion/retention, security, production-data investigation, or migration/rollout risk | Investigation when uncertainty exists + brief + recommendation + living plan + full validation/release record |

The classification is a planning aid, not permission to skip safety work. A
small-looking change becomes Level L as soon as it crosses a public contract,
data boundary, repository boundary, or destructive operation. When uncertain,
choose the larger level and document why.

## Artifact lifecycle

Every Level M or L change gets a stable slug, for example
`pdf-template-management` or `payroll-update-delete`.

Register the slug in `docs/proposals/INDEX.md` when the investigation,
brief, or recommendation is created, and update its status at every lifecycle
transition.

### Required artifacts

| Artifact | Path | Purpose | Lifecycle |
| --- | --- | --- | --- |
| Investigation | `modules/*/docs/investigations/<slug>.md` | Evidence and current-state analysis | Closed after findings are resolved; may receive factual corrections |
| Brief | `modules/*/docs/proposals/<slug>-brief.md` | Problem, constraints, acceptance criteria, and questions for design | Frozen after approval; supersede rather than silently rewrite |
| Recommendation | `modules/*/docs/proposals/<slug>-recommendation.md` | Design decision, alternatives, contracts, and acceptance criteria | Decision record; amend only when the decision changes |
| Plan | `modules/*/docs/proposals/<slug>-plan.md` | Ordered implementation slices and live progress | Living document through implementation and rollout |

For a cross-repository change, artifacts live in the repository/module that
initiated the change and are linked from the other affected modules' docs or
README files through `Related artifacts`. The initiating repository
owns the coordination record; each affected repository still owns its code,
tests, migrations, and release status. If the change is genuinely ecosystem-
wide rather than initiated by one module, use the root `docs/proposals/` area.

## Out-of-scope findings

During investigation or implementation, a valid improvement may be discovered
that is unrelated to the primary task. Do not expand the active brief,
recommendation, or plan with that improvement. Add a concise, sanitized entry to
the [PF Ecosystem Improvement Register](proposals/ECOSYSTEM-IMPROVEMENT-REGISTER.md)
instead.

The register entry must include:

- a short summary;
- type of improvement;
- importance and estimated size;
- owner and affected repositories;
- source artifact where it was discovered;
- a unique numeric priority ranking, where `1` is the first item to take;
- blocking relationships: `Blocked by`, `Blocks`, and `Blocking scope`;
- next action, resolution when applicable, and related links.

Use `none` when no dependency is known. `Blocking scope` distinguishes
`local preparation`, `migration`, `cutover`, `release`, and `incident response`.
Do not infer a dependency merely because entries share a repository. The active
task may continue through local preparation when a follow-up blocks only
migration, cutover, or release.

`Priority` is a unique positive integer across active register entries. Active
statuses are `planned`, `investigating`, `designed`, `approved`, `in progress`,
and `blocked`; completed or discarded statuses (`validated`, `released`,
`superseded`, and `closed`) must use `—` instead of a live priority. Recalculate
the complete active ranking whenever an entry is added, its status changes, a
blocker changes, or the critical path changes. Priority is an execution-order
recommendation, not authorization. Critical security findings still require
immediate escalation.

Critical security, privacy, data-loss, production-safety, and credential findings
must be escalated immediately. Registering the finding is required, but it does
not replace urgent containment or incident response and must not delay it.

When the improvement receives explicit authorization, promote it to the normal
proposal lifecycle: create the applicable artifacts, add Level M/L work to
`docs/proposals/INDEX.md`, and link the formal proposal from the register entry.
The original task plan should retain only a short cross-reference to the entry.

`*-action-plan.md` is accepted for historical compatibility, but all new work
should use `*-plan.md`. A plan is mandatory for Level L work. For Level M,
the recommendation may contain a short implementation checklist instead of a
separate plan. Level S does not require proposal artifacts.

The existing documents demonstrate why this separation matters: the PDF
import, spreadsheet export, PDF template, and batch lookup plans contain useful
implementation corrections and live validation results, while some
recommendations and briefs are better treated as frozen design records. The
batch lookup work also shows that skipping a redundant artifact is reasonable
when the investigation has already resolved the questions; that exception must
be stated at the top of the plan.

## GCP access via Cloud Shell scripts
When an agent needs to obtain information from or execute an action in GCP and
cannot do so directly because of network, VPC Service Controls, or equivalent
restrictions, the agent must not assume results or ask the user for loose commands.
It must prepare a Cloud Shell `.sh` script and give the user one controlled entry
point.
### Script location and versioning
- Store the script under `<module>/docs/cloudshell/`, or under
  `docs/cloudshell/` at the root when no module owns the work.
- `cloudshell/` is ignored and scripts in it are **not versioned**.
- Before creating or updating a script, run `git check-ignore -v <script-path>`
  from the owning repository. If the path is already tracked, tell the user and do
  not silently bypass tracking.
- Every `modules/*/docs/` and the root `docs/` must contain a `.gitignore` with:
  ```gitignore
  cloudshell/
  ```
  Add the line only when absent and preserve all other `.gitignore` content. A new
  module must create this `.gitignore` when its `docs/` directory is created.
- Use `<improvement-id>-gcp-<nn>.sh`, for example `imp-001-gcp-01.sh`, with a
  sequence number unique within the improvement.
- Do not mention the script name, path, downloaded archive, or archive contents in
  versioned investigations, briefs, recommendations, plans, logs, commits, or PRs.
  Versioned artifacts may contain only sanitized conclusions and decisions.
### Required script behavior
Every Cloud Shell script must:
1. Start with `#!/usr/bin/env bash`, `set -euo pipefail`, and `umask 077`; never use
   `set -x`.
2. Define an explicit `PROJECT_ID` near the top. Do not silently infer the project.
   Validate the project with `gcloud projects describe` and validate an active session
   before doing anything else.
3. Be read-only by default. If mutation is required, list the resources first, ask
   for interactive `y/N` confirmation, check whether each resource already exists,
   and make the operation idempotent.
4. Create `<id>-gcp-<nn>-<timestamp UTC YYYYMMDDTHHMMSSZ>` in the current directory
   and write every result there.
5. Never print or persist secrets, tokens, passwords, connection strings, raw
   payloads, or sensitive headers. Read secrets only in memory when strictly
   necessary, unset them afterward, and report only metadata or a truncated hash
   when comparison is required. Redact sensitive `gcloud` output before saving it.
6. Write each query to its own structured file, preferably with `--format=json`, and
   create `summary.md` containing commands, findings, errors, and created resources
   plus their cleanup command.
7. Use a trap that records the failed step in `summary.md` without exposing data;
   preserve partial results for diagnosis.
8. Compress the work directory as `<same-name>.tar.gz` in the current directory,
   verify `tar -tzf` succeeds and the archive size is greater than zero, then remove
   the work directory. Never automatically remove the archive or the script.
9. Finish by printing, in this order:
   - a local-terminal download command built from the actual archive path and
     project ID, using `gcloud cloud-shell scp cloudshell:... localhost:./`;
   - a Cloud Shell cleanup command using absolute paths resolved from
     `realpath "${BASH_SOURCE[0]}"`.
The cleanup command must warn the user not to run it until the local archive has
been verified. If `cloudshell download` is used, do not delete immediately after
it returns: the browser transfer may still be pending.
### Base template
Copy and adapt this template in the ignored `docs/cloudshell/` directory. Keep the
project ID explicit, replace the example read-only query, and preserve the safety
boundaries:
```bash
#!/usr/bin/env bash
set -euo pipefail
umask 077
PROJECT_ID="REPLACE_PROJECT_ID"; ID="imp-xxx"; N="01"
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"; BASE="$PWD"
RUN="${ID}-gcp-${N}-$(date -u +%Y%m%dT%H%M%SZ)"; DIR="$BASE/$RUN"; ARCHIVE="$BASE/$RUN.tar.gz"
STEP=init
fail() { s=$?; printf 'status=failed step=%s exit_code=%s\n' "$STEP" "$s" >&2; exit "$s"; }
trap fail ERR
command -v gcloud >/dev/null || exit 1; command -v tar >/dev/null || exit 1
[[ "$PROJECT_ID" != REPLACE_PROJECT_ID ]] || { printf 'replace PROJECT_ID\n' >&2; exit 2; }
mkdir -m 700 "$DIR"
STEP=project; gcloud projects describe "$PROJECT_ID" --format=json >"$DIR/project.json"
STEP=session; gcloud auth list --filter=status:ACTIVE --format='value(account)' >"$DIR/session.txt"
grep -q . "$DIR/session.txt"
STEP=query; gcloud resource-manager projects describe "$PROJECT_ID" --format=json >"$DIR/query.json"
STEP=summary; printf '# Summary\n\n- project: %s\n- mutations: none\n- secrets: none\n' "$PROJECT_ID" >"$DIR/summary.md"
STEP=archive; tar -czf "$ARCHIVE" -C "$BASE" "$RUN"; tar -tzf "$ARCHIVE" >/dev/null
size="$(stat -c %s "$ARCHIVE" 2>/dev/null || stat -f %z "$ARCHIVE")"; [[ "$size" -gt 0 ]]
rm -rf -- "$DIR"
rel="${ARCHIVE#$HOME/}"; [[ "$rel" != "$ARCHIVE" ]] || rel="$ARCHIVE"
printf 'success=true archive_size=%s\n' "$size"
printf 'gcloud cloud-shell scp cloudshell:~/%s localhost:./ --project=%s\n' "$rel" "$PROJECT_ID"
printf 'Verify the local archive before cleanup; then run in Cloud Shell:\nrm -f -- %q %q\n' "$ARCHIVE" "$SCRIPT_PATH"
```
## Neon access via local execution scripts
When an agent needs Neon information or an action through the Neon API, `neonctl`,
or SQL via `psql`, but network/VPC restrictions prevent direct access, the agent must
not assume results or ask for loose commands. It must prepare a local `.sh` script for
the user to execute on their machine.
### Location and versioning
- Store the script under `<module>/docs/neon/`, or root `docs/neon/` when no module
  owns the work.
- `neon/` is ignored and scripts/results are **not versioned**.
- Before creating/updating a script, run `git check-ignore -v <script-path>` from the
  owning repository. If already tracked, report it and do not silently bypass tracking.
- Every module `docs/` and root `docs/` must contain `neon/` in `.gitignore`, preserving
  all other rules. New modules add it when `docs/` is created.
- Name scripts `<improvement-id>-neon-<nn>.sh`, with a sequence unique to the improvement.
- Do not mention the script name/path, result directory, downloaded results, or their
  contents in versioned artifacts. Record only sanitized conclusions.
### Required script behavior
Every Neon script must:
1. Use `#!/usr/bin/env bash`, `set -euo pipefail`, `umask 077`, and never `set -x`.
2. Define explicit `PROJECT_ID`, `BRANCH`, and `DATABASE` variables; validate the
   project and branch before showing the target context.
3. Check required binaries (`neonctl`, `psql`, `jq`, etc.) and print installation
   guidance before aborting when one is missing.
4. Use `neonctl auth`, `NEON_API_KEY`, or a single-line credential file explicitly
   documented by the module and ignored under `neon/`; credential files must be mode
   `600`. Never accept credentials as arguments. If a value is needed interactively,
   use `read -rs`. For SQL, capture the connection string in memory and use a `mktemp`
   `pgpass` file with mode `600`, `sslmode=require`, and an unconditional trap.
5. Use the least-privileged role. Warn in console and `summary.md` before using an
   owner role. Unset sensitive variables immediately after use.
6. Be read-only by default: use `BEGIN READ ONLY`, `default_transaction_read_only=on`,
   and a reasonable `statement_timeout`. Mutations require a listed action and `y/N`
   confirmation, must be idempotent, and schema/data changes should use a temporary
   Neon branch first.
7. Never extract raw business/personal data. Prefer schema, index, size, count,
   explain, and configuration metadata; mask sensitive columns and keep samples tiny.
8. Create `<id>-neon-<nn>-<YYYYMMDDTHHMMSSZ>` in the current directory, verify it is
   ignored with `git check-ignore -v`, and write every result there.
9. Put each query in its own structured file (`neonctl --output json`, CSV, or
   unaligned `psql`) and write `summary.md` with target context, commands, findings,
   errors, resources, and cleanup commands. Never write credentials or connection strings.
10. Use a failure trap that records the failed step without sensitive data, removes the
    temporary `pgpass`, and preserves partial results.
### Base template
Adapt this template in the ignored `docs/neon/` directory; keep credentials out of
arguments and source:
```bash
#!/usr/bin/env bash
set -euo pipefail
umask 077
PROJECT_ID="REPLACE_PROJECT_ID"; BRANCH="REPLACE_BRANCH"; DATABASE="REPLACE_DATABASE"
ID="imp-xxx"; N="01"; STEP=init; SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"; CREDENTIAL_FILE="$SCRIPT_DIR/neon-credentials.txt"
BASE="$PWD"; RUN="${ID}-neon-${N}-$(date -u +%Y%m%dT%H%M%SZ)"; DIR="$BASE/$RUN"
PGPASS_FILE="$(mktemp)"; trap 'rm -f "$PGPASS_FILE"' EXIT
fail() { s=$?; printf 'status=failed step=%s exit_code=%s\n' "$STEP" "$s" >&2; exit "$s"; }
trap fail ERR
for c in neonctl psql jq; do command -v "$c" >/dev/null || exit 1; done
[[ "$PROJECT_ID" != REPLACE_PROJECT_ID && "$BRANCH" != REPLACE_BRANCH && "$DATABASE" != REPLACE_DATABASE ]]
mkdir -m 700 "$DIR"; git check-ignore -q "$DIR/.keep"
[[ -f "$CREDENTIAL_FILE" ]] && [[ "$(stat -c %a "$CREDENTIAL_FILE" 2>/dev/null || stat -f %Lp "$CREDENTIAL_FILE")" == 600 ]]
NEON_DATABASE_URL="$(cat "$CREDENTIAL_FILE")"
STEP=validate; neonctl projects get "$PROJECT_ID" --output json >"$DIR/project.json"; neonctl branches get "$BRANCH" --project-id "$PROJECT_ID" --output json >"$DIR/branch.json"
# No secret is printed. Parse NEON_DATABASE_URL in memory and write only the
# temporary 600-mode PGPASS_FILE before read-only psql execution.
# PGPASSFILE="$PGPASS_FILE" psql "$DATABASE" -X -v ON_ERROR_STOP=1 --set=statement_timeout=30000 --command='BEGIN READ ONLY; SELECT ...; COMMIT;' >"$DIR/query.csv"
printf '# Summary\n\n- project: %s\n- branch: %s\n- database: %s\n- mutations: none\n' "$PROJECT_ID" "$BRANCH" "$DATABASE" >"$DIR/summary.md"
```
## Step 0 — Investigation (optional, mandatory when uncertainty exists)
Start with an investigation when the request involves unknown consumers,
production behavior, a suspected defect, an API/schema change, deletion,
security, legal retention, or cross-repository behavior.

The investigation must include:

- date, scope, repositories inspected, and status;
- current source-of-truth files and exact route/table/workflow locations;
- observed consumers, traffic, logs, or production evidence, with timestamps;
- current behavior and the behavior that is actually desired;
- dependency/FK/schema ownership audit;
- compatibility and migration risks;
- open questions requiring a user decision;
- a conclusion: proceed, redesign, defer, or close as non-actionable.

Separate facts, inferences, and assumptions. Never promote historical traffic
or a superseded recommendation into the current contract without rechecking
OpenAPI and source code. The payroll operation-endpoint investigation is the
model here: it explicitly distinguishes historical requests from the current
surface and verifies OpenAPI, API docs, and Postman together.

**Exit criteria:** the unknowns that affect scope are resolved or listed as
explicit user decisions. If the investigation finds no change is needed, close
it with that conclusion instead of manufacturing implementation work.

## Step 1 — Brief

The brief is the implementation-independent instruction that asks for a design
recommendation. It must be precise enough that another agent can produce the
same recommendation without rediscovering the system.

Include:

- objective and non-objectives;
- affected repositories and architectural boundaries;
- current behavior, with evidence from the investigation when present;
- constraints and non-negotiable invariants;
- compatibility and acceptance criteria stated as observable outcomes;
- required documentation and synchronization work at a high level;
- testing expectations at a high level;
- cost and operational questions;
- questions that must be answered before design or implementation;
- requested recommendation format.

The brief defines acceptance as observable outcomes. The recommendation
converts those outcomes into verifiable criteria: tests, commands, expected
responses, schema assertions, or release checks.

The brief should not decide the exact route shape, DTO fields, migration
algorithm, locking strategy, or error status unless an existing contract or an
explicit user decision already fixes it. Those design decisions belong in the
recommendation. This keeps the brief a problem/constraint/acceptance document
instead of making the recommendation a confirmation exercise.

**Exit criteria:** the brief is internally consistent, has no hidden scope, and
all required user decisions are either confirmed or clearly marked as blockers.
The brief is then frozen. Corrections become an amendment or a new superseding
brief, not silent historical rewriting.

## Step 2 — Recommendation

The recommendation answers the brief against the real codebase. It is not an
implementation log and must not claim that code exists unless it already
existed before this work.

A recommendation may reject part of the original request. It must say so
plainly, as the batch lookup recommendation did for `pf-sheets` and as the
spreadsheet recommendation did for computed-only columns.

It must contain:

1. executive recommendation and rejected alternatives;
2. current-code evidence and affected call paths;
3. domain/application/interface/infrastructure placement;
4. exact API, DTO, port, persistence, and migration contracts;
5. transaction, locking, idempotency, rollback, and error matrix;
6. cross-repository sequencing and ownership;
7. test strategy, including important negative and integration cases;
8. docs/OpenAPI/Postman/workflow synchronization;
9. rollout, compatibility, observability, and rollback strategy;
10. cost impact, measured across applicable categories, and cheaper alternatives considered;
11. explicit final decision and remaining user approvals.

For Level M, mark non-applicable sections `N/A — <one-line reason>` rather
than inventing architecture, migration, rollout, or cost detail that does not
apply. Level L requires every applicable section and a reason for every N/A.
Level S does not require a recommendation.

The recommendation is a design-time decision record. During implementation,
contract details may be corrected in the plan when the actual code or existing
compatibility requires it. Once released, the source of truth for a public
contract is the code, generated OpenAPI (or the Apps Script webapp interface),
`docs/api.md`, and the synchronized Postman collection. The recommendation then
becomes historical context; it must not be used to contradict the released
contract. Record the correction and its reason in the plan's change log.

Cost impact must identify the applicable category and measurement:

- **Infrastructure:** services, instances, storage, network, database, and
  scanning changes; estimate recurring and one-time cost.
- **API/provider usage:** request volume, paid calls, quotas, cache effects,
  and expected latency/cost changes.
- **Data operations:** migration size, retention, backup, and query/storage
  impact.
- **Engineering/operations:** recurring maintenance, support, rollout, and
  rollback complexity when infrastructure cost is zero.

State the cheapest viable alternative considered and why it was rejected or
selected. “No new infrastructure” is a valid conclusion, but it still needs to
say what operational or engineering cost remains.

### Decision gate and approval record

Implementation does not begin while a recommendation still has unresolved
decisions that can change the architecture, public contract, schema, retention
policy, or destructive behavior. The user approves the recommendation or
explicitly authorizes implementation despite those items.

Record the gate in the artifact metadata, for example:

```text
Status: approved
Approved: 2026-10-04 by Arturo (conversation | PR #N)
Superseded-by: none
```

For a superseded artifact, preserve the old record and set:

```text
Status: superseded
Superseded-by: <new-slug-or-artifact>
```

Do not infer approval from a conversational hint, a local test run, a commit, or
an earlier unrelated approval.

## Step 3 — Plan

Before implementation, derive a living plan from the approved recommendation.
The plan should contain:

- status (use the controlled list in **Naming and status conventions**);
- implementation slices in dependency order;
- files/repositories expected to change;
- migration and rollout order;
- per-slice tests and exit criteria;
- decisions made during implementation;
- deviations and corrections, each with date and reason;
- validation commands and results;
- live-environment checks, if performed;
- docs/Postman synchronization checklist;
- change log and final release notes.

Typical order:

1. `pf-db` migration and seed changes, if required;
2. domain/application ports and DTOs;
3. infrastructure adapters and repositories;
4. interface routes and dependency wiring;
5. tests and fixtures;
6. API docs, OpenAPI checks, Postman, and operational docs;
7. local quality gates;
8. commit/push and CI monitoring;
9. deployment approval and smoke validation.

A migration must land before code that depends on it reaches traffic. If no
migration is needed, record the dependency audit and why.

## Step 4 — Implementation

Implement only the approved scope, preserving the architecture and existing
behavior outside that scope.

During implementation:

- update the living plan after each meaningful slice;
- record discoveries and corrections with dates;
- update the recommendation only if a design decision changes, and link to the
  plan entry explaining why;
- reuse existing pipelines rather than duplicating domain calculations;
- add tests before declaring a new branch complete;
- use synthetic fixtures and stub external services.

For public APIs, verify the generated OpenAPI against `docs/api.md` and the
Postman collection before committing. For schema work, verify migration
upgrade/downgrade and update `pf-db` table/migration documentation.

## Step 5 — Validation and release

Run the narrowest relevant tests during development, then the repository's
complete quality gate before push. For Python services this normally includes
lint, formatting, dead-code, mypy, duplicate-code, full tests, coverage, and
security scanning. For `pf-sheets`, use its Node/Apps Script lint and test
workflow instead.

Record in the plan:

- commands and exact results;
- known environmental blockers, such as unavailable Docker;
- any tests intentionally not run and why;
- generated OpenAPI/API/Postman comparison results;
- deployment run IDs and final conclusions.

Follow the owning repository's `AGENTS.md` for the mandatory pre-push active-run
cleanup, explicit push authorization, manual approval rules, and post-push
monitoring sequence.

Only after explicit user authorization:

1. create a conventional commit in each affected repository;
2. push each repository independently;
3. monitor the relevant workflow by commit SHA;
4. investigate and fix failures rather than rerunning blindly;
5. approve manual deployment gates only when explicitly requested;
6. verify deployment smoke tests and record the final URL/run status.

A workflow is not “done” because push succeeded. It is done when the relevant
checks and deployment outcome are known, or when a clearly documented external
blocker remains.

## Step 6 — Close and improve the process

After validation or release, the plan must end with a short final summary:
what shipped, what did not, which artifacts are authoritative, and which
follow-ups remain. Update the single central index
`docs/proposals/INDEX.md` with the final status, commit/run references, and
authoritative contract locations. Keep unrelated follow-ups in the
[PF Ecosystem Improvement Register](proposals/ECOSYSTEM-IMPROVEMENT-REGISTER.md)
rather than expanding the completed task artifacts. Ask explicitly: **did this work reveal a change
needed in this workflow?** If yes, update this workflow through a normal
documented change; do not let process changes exist only in memory.

## Definition of done

An improvement is complete when all applicable items are true:

- **S:** relevant tests/quality gates pass and the commit description records
  the change and verification;
- **M:** the recommendation checklist is complete, tests/quality gates pass,
  and any changed docs/contracts are synchronized;
- **L:** investigation is closed or explicitly skipped with rationale, brief is
  frozen, recommendation is approved, plan records implementation progress and
  deviations, cross-repository sequencing is complete, and release/CI status is
  recorded.

For M and L, additionally, where applicable:

- code follows the owning repository's architecture and language rules;
- schema ownership and migration order are correct;
- tests cover success, failure, rollback, compatibility, and concurrency;
- required quality gates pass;
- API docs, OpenAPI, Postman, and operational docs agree;
- cost impact is recorded;
- all affected repositories are committed and pushed only with authorization;
- CI/deployment is monitored through its final state.

For every level:

- unresolved follow-ups have owners and are not disguised as completed work.

## Naming and status conventions

Use one slug across every artifact:

```text
<slug>-brief.md
<slug>-recommendation.md
<slug>-plan.md
```

For Level S, no proposal metadata is required. For Level M and L, begin each
artifact with `Date`, `Status`, `Level`, `Scope`, `Related artifacts`,
`Approved`, and `Superseded-by`.

Use one controlled status list for every artifact and for the central index:

```text
planned | investigating | designed | approved | in progress | blocked |
validated | released | superseded | closed
```

Meanings:

- `planned`: work is identified but investigation/design has not started;
- `investigating`: evidence collection is active;
- `designed`: recommendation exists but its decision gate is not approved;
- `approved`: the recommendation is explicitly approved for implementation;
- `in progress`: implementation or validation is active;
- `blocked`: progress cannot continue until an external dependency or user
  decision is resolved;
- `validated`: implementation and quality checks pass, but release/deployment
  evidence is not complete or does not apply;
- `released`: the approved change is deployed or otherwise made available in
  its target environment, with the release evidence recorded;
- `superseded`: replaced by another artifact or decision;
- `closed`: investigated or designed work intentionally ended without a release,
  including non-actionable findings.

`Status` is lifecycle state only. Notes such as `metadata stale` or `release
to verify` belong in a separate `Notes` field in the index or a change log.

When a later session changes reality, preserve the prior conclusion in the
change log and state which artifact is now authoritative. Do not leave two
files that both claim to be the current source of truth.
