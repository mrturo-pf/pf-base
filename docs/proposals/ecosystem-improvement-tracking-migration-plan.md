# Plan: ecosystem improvement tracking migration

Date: 2026-10-12
Status: in progress
Level: L
Scope: Migrate PF improvement tracking to a GitHub-centered operating model while preserving Git-based investigations, decisions, plans, and evidence.
Related artifacts: [investigation](../investigations/ecosystem-improvement-tracking-migration.md) · [brief](ecosystem-improvement-tracking-migration-brief.md) · [recommendation](ecosystem-improvement-tracking-migration-recommendation.md) · [register](ecosystem-improvement-register.md) · [workflow](../ecosystem-improvement-workflow.md)
Approved: 2026-10-12 by owner (conversation)
Superseded-by: none

## 1. Gates

- [x] Investigation opened and current documentation model recorded.
- [x] Brief drafted with scope, constraints, acceptance criteria, and pilot.
- [x] Recommendation drafted with source-of-truth boundaries and alternatives.
- [x] Read-only GitHub capability and permission check completed.
- [x] `read:project` scope added and Projects query completed.
- [x] Recommendation explicitly approved by the owner.
- [x] Project creation and pilot migration explicitly authorized.
- [x] Metadata schema and Issue template approved.
- [x] Pilot reconciliation passes.
- [ ] Validation and generation workflows pass negative tests.
- [ ] Agent read-only retrieval is validated.
- [ ] Historical migration is authorized and reconciled.
- [ ] Workflow is updated with the validated steady-state process.
- [ ] Release and closure evidence recorded.

No Project, Issue, permission, or Actions mutation is authorized while the first
six gates are incomplete.

## 2. Implementation slices

### Slice 1 — Capability and permission inventory

Perform an authorized, read-only GitHub check for Project availability, repository
visibility, API access, Actions capabilities, account/organization scope, and
permission outcomes. Record metadata only; never persist tokens or sensitive
payloads.

**Exit criteria:** capability assumptions in the investigation are resolved,
unsupported features are identified, and the recommendation is confirmed or
returned for amendment.

### Slice 2 — Approval and metadata contract

Record owner approval or the decision to amend the design. Define the metadata
schema, controlled values, templates, canonical-link rules, and transition
reconciliation behavior.

**Exit criteria:** schema fixtures and required Level M/L artifact rules are
reviewable and approved.

### Slice 3 — Project and pilot coordination objects

After explicit authorization, create the ecosystem Project, mandatory fields,
initial views, and exactly one Issue for each pilot item: IMP-006, IMP-007, and
IMP-009. Link each item to its canonical Git artifacts.

**Exit criteria:** pilot Project items and Issues reconcile with the current index,
register, and plans; no historical artifact is rewritten.

### Slice 4 — Repository validation

Implement validation for metadata, IDs, slugs, statuses, priorities, links,
required artifacts, sensitive-content boundaries, and generated-output determinism.
Start with pull-request validation and read-only behavior.

**Exit criteria:** valid fixtures pass and invalid fixtures fail with actionable
messages.

### Slice 5 — Generated navigation and context

Generate `improvements.json`, `agent-context.md`, `agent-context.json`, and a
static dashboard from approved inputs. Clearly mark generated files and preserve
canonical links and current/historical distinctions.

**Exit criteria:** generation is deterministic, sanitized, reviewable, and useful
for read-only agent retrieval.

### Slice 6 — Read-only agent retrieval

Validate that the agent can retrieve Project operational data, Issues, generated
context, and canonical repository documents with the minimum required permissions.
Test permission denial and missing-data behavior.

**Exit criteria:** the agent can answer active, blocked, recently changed,
superseded, and awaiting-approval queries without mutation access.

### Slice 7 — Historical migration

After pilot validation and explicit authorization, migrate remaining active and
historical entries using defined treatment for released, superseded, closed, and
incomplete work. Preserve stable IDs and historical links.

**Exit criteria:** all migrated items reconcile with the repository records and
any metadata gaps are explicitly recorded rather than inferred.

### Slice 8 — Steady-state and closure

Generate or retire duplicate Markdown views only after reconciliation. Update the
workflow, document ownership and failure recovery, record costs and run evidence,
and close the improvement with follow-ups separated into the register.

**Exit criteria:** Definition of Done is complete and the final authoritative
sources are documented.

## 3. Files and systems expected to change

Root repository:

- `docs/ecosystem-improvement-workflow.md` after the target process is validated;
- `docs/proposals/index.md` during transition or as generated output;
- `docs/proposals/ecosystem-improvement-register.md` during transition;
- metadata/template directories;
- GitHub Actions workflows and validation scripts;
- generated dashboard and agent-context outputs, according to the final hosting
  decision.

GitHub:

- one ecosystem Project;
- pilot Project items and Issues;
- Issue template and documented field/view conventions.

Module repositories should change only when they own a required artifact, local
link, or repository-specific automation. No service runtime change is expected.

## 4. Capability inventory

Read-only GitHub verification completed on 2026-10-12:

| Check | Result |
|---|---|
| `gh` authentication | Passed for `mrturo` |
| Repository | `mrturo-pf/pf-base` |
| Repository visibility | Public |
| Default branch | `main` |
| Viewer permission | `ADMIN` |
| GitHub API access | Passed for user and repository metadata |
| Projects API access | Passed with `read:project` scope |
| User Projects visible | None |
| Organization Projects visible for `mrturo-pf` | None |
| Current token scopes observed | `copilot`, `gist`, `read:org`, `read:project`, `repo`, `workflow` |

The read-only capability check is complete. At the time of the check no Project
existed for the user or `mrturo-pf`; the authorized pilot Project was subsequently
created and configured. No unauthorized GitHub mutation occurred during the check.

## 5. Pilot operational record

Created with explicit owner authorization on 2026-10-12 and 2026-10-13:

- Project: [PF Ecosystem Improvements](https://github.com/orgs/mrturo-pf/projects/1)
- `IMP-006`: [Issue #1](https://github.com/mrturo-pf/pf-base/issues/1)
- `IMP-007`: [Issue #2](https://github.com/mrturo-pf/pf-base/issues/2)
- `IMP-009`: [Issue #3](https://github.com/mrturo-pf/pf-base/issues/3)
- `IMP-010`: [Issue #4](https://github.com/mrturo-pf/pf-base/issues/4)

The Project contains the four pilot items with populated operational fields:
`Status`, `Priority`, `Size`, `Work type`, `Owner`, `Affected repositories`,
`Blocking scope`, `Improvement ID`, `Slug`, `Last verified`, and `Canonical plan`.
The Project's native `Type` field name was reserved by GitHub, so the custom field
is named `Work type`.

Read-only reconciliation on 2026-10-13 confirmed exactly four Project items and
matching `Improvement ID`/`Slug` values for `IMP-006`, `IMP-007`, `IMP-009`, and
`IMP-010`. The fourth item is [Issue #4](https://github.com/mrturo-pf/pf-base/issues/4).

## 6. Slice 4 validation evidence

Implemented in the root repository:

- transition manifest: `docs/proposals/improvements.json`;
- validator and generator: `scripts/validate-improvements.py`;
- read-only workflow: `.github/workflows/improvement-validation.yml`;
- Issue template: `.github/ISSUE_TEMPLATE/improvement.md`;
- generated outputs: `docs/generated/improvements.json`,
  `docs/generated/agent-context.md`, and
  `docs/generated/improvements-dashboard.html`;

Local validation passed:

```text
python3 scripts/validate-improvements.py --write-generated
python3 scripts/validate-improvements.py
git diff --check
python3 scripts/check-language.py --all
```

The negative fixture for a duplicate improvement ID failed as expected. The GitHub
workflow performs no Project synchronization and uses `contents: read` only. Its
first run passed on commit `a038395dd3a9d2fed9acfa6ba4ebd2cbcdc76396`:

```text
CI / Documentation language: run 38393766846 — success
Improvement metadata validation: run 38393766923 — success
```

## 7. Validation commands and evidence

Planned local checks:

```text
python3 scripts/check-language.py --all
git diff --check
metadata validator with valid and invalid fixtures
generated-output determinism check
link and required-artifact validation
```

Planned GitHub checks:

```text
read-only capability inventory
Project/Issue-to-artifact reconciliation
read-only agent retrieval
permission-denial behavior
workflow run and artifact inspection
```

Record exact commands, results, workflow run IDs, permission outcomes, and known
environmental blockers here as slices complete. Do not record credentials or raw
sensitive responses.

## 5. Rollback

If the pilot fails:

1. stop any synchronization workflow;
2. preserve Project and Issue history;
3. restore the last valid generated/index snapshot;
4. disable publication if it exposes incorrect or unauthorized content;
5. retain Git artifacts and stable IDs;
6. record the discrepancy, impact, and follow-up decision;
7. retry only after the recommendation or schema is amended and approved.

Rollback must not delete historical investigations, plans, Issues, Project items,
commits, or release evidence.

## 6. Change log

| Date | Status | Change | Evidence |
|---|---|---|---|
| 2026-10-12 | investigating | Opened IMP-010 investigation and recorded current-state and option assessment. | Investigation artifact |
| 2026-10-13 | in progress | Created and configured the `IMP-010` coordination Issue #4; reconciled four Project items against the transition manifest. | Project #1, Issue #4, read-only item-list output |
| 2026-10-13 | in progress | Added transition manifest, deterministic agent-context generation, read-only validation workflow, and Issue template. Valid and duplicate-ID negative tests passed locally; CI run pending. | Local validator and generated outputs |
| 2026-10-12 | in progress | Created the organization Project and three authorized pilot Issues; populated operational fields and verified the resulting items. | Project #1, Issues #1–#3 |
| 2026-10-12 | designed | Read-only GitHub Projects verification passed after adding `read:project`; no user or organization Projects exist. No GitHub mutation performed. | GitHub GraphQL Projects query |
| 2026-10-12 | designed | Read-only GitHub verification passed for repository metadata; Projects query initially blocked by missing `read:project` scope. No GitHub mutation performed. | `gh auth status`, GitHub API user/repository query |
| 2026-10-12 | designed | Drafted brief, recommendation, and implementation slices. No GitHub mutation performed. | Brief and recommendation |

## 7. Release record

- Project URL: https://github.com/orgs/mrturo-pf/projects/1
- Pilot Issues: #1, #2, and #3 created and added to the Project
- Workflow runs: pending
- Agent retrieval validation: pending
- Owner approval: recorded 2026-10-12
- Historical migration approval: pending
- Rollback evidence: pending
- Final authoritative sources: pending
- Follow-ups: IMP-010 coordination Issue decision pending
