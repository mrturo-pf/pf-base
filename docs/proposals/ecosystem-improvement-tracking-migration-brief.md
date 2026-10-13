# Brief: ecosystem improvement tracking migration

Date: 2026-10-12
Status: approved
Level: L
Scope: Migrate PF improvement tracking to a GitHub-centered operating model while preserving Git-based investigations, decisions, plans, and evidence.
Related artifacts: [investigation](../investigations/ecosystem-improvement-tracking-migration.md) · [recommendation](ecosystem-improvement-tracking-migration-recommendation.md) · [plan](ecosystem-improvement-tracking-migration-plan.md) · [register](ecosystem-improvement-register.md) · [workflow](../ecosystem-improvement-workflow.md)
Approved: 2026-10-12 by owner (conversation)
Superseded-by: none

## Objective

Define a safe, auditable, and agent-accessible operating model for tracking PF
ecosystem improvements. The model must provide a visual operational queue and
structured queries without moving durable technical evidence out of Git or
weakening the existing lifecycle gates.

## Non-objectives

- Replacing Git as the source of investigations, design decisions, plans, code,
  API documentation, or release evidence;
- rewriting historical artifacts solely to fit a new tool;
- changing service behavior, schemas, APIs, deployments, or production access;
- granting the agent autonomous authority to mutate repositories, projects,
  permissions, or production systems;
- introducing a paid project-management or observability product without an
  approved cost and operational justification;
- collecting credentials, raw production payloads, personal data, financial data,
  health data, or unsanitized operational evidence;
- retiring the existing Markdown index or register before the replacement is
  validated and reconciliation is repeatable.

## Current behavior

The ecosystem workflow defines lifecycle states, planning levels, artifact
responsibilities, approval gates, cross-repository ownership, validation, release,
and closure rules. The central index and improvement register provide navigation
and intake, while detailed state and evidence are distributed across plans and
module documentation.

This is durable but difficult to operate as a queue. The same improvement may
require reading several Markdown files to determine its current state, blockers,
next action, and authoritative evidence. The desired change is an operational
projection and query layer, not a replacement for the documentation lifecycle.

## Target operating model

| Concern | Target |
|---|---|
| Current operational status, priority, ownership, affected repositories, and blockers | GitHub Project |
| Improvement discussion and coordination | One GitHub Issue per improvement |
| Investigations, briefs, recommendations, plans, contracts, and evidence | Owning Git repository |
| Metadata and link consistency | GitHub Actions validation |
| Generated index and dashboard | GitHub Actions output |
| Agent retrieval context | Generated sanitized Markdown and structured JSON |
| Process rules and lifecycle gates | `docs/ecosystem-improvement-workflow.md` |

The target must define one authoritative location for each field. It must not
create a second manually maintained project register beside the GitHub Project.

## Required outcomes

1. Every active improvement has one stable ID and slug.
2. Every active improvement has exactly one coordination Issue.
3. Every Level M/L improvement links its required Git artifacts.
4. The operational queue supports filtering by status, priority, owner, affected
   repository, type, size, blocker, and last verification date.
5. The controlled workflow statuses remain unchanged unless a separate process
   decision approves an amendment.
6. The generated index and dashboard are reproducible from structured metadata and
   approved GitHub data.
7. The generated agent context identifies active work, canonical artifacts,
   blockers, recent validation, superseded decisions, and unresolved questions.
8. Validation detects missing links, duplicate IDs, invalid statuses, inconsistent
   level requirements, stale metadata, and unsafe sensitive content patterns where
   practical.
9. The pilot can be rolled back without deleting historical Git artifacts or losing
   the existing Markdown register and index.
10. The operating model can be used without adding always-on infrastructure.

## Acceptance criteria

### Process and source of truth

- A documented mapping exists between workflow artifacts and GitHub objects.
- The Project is authoritative for current operational fields, while Git remains
  authoritative for technical evidence and decisions.
- The transition rule for reconciling existing Markdown state with Project state is
  explicit and tested.
- Released, superseded, closed, incomplete, and active historical entries each have
  a defined migration treatment.

### GitHub Project and Issues

- The pilot Project has documented fields, allowed values, views, and permissions.
- Each pilot improvement has one Issue linked to its canonical artifacts and Project
  item.
- The Issue template prevents omission of ID, slug, owner, affected repositories,
  scope, next action, and canonical links.
- Blockers and dependencies are represented without duplicating unrelated technical
  evidence in the Issue.

### Repository automation

- A validation workflow runs on relevant Markdown and metadata changes.
- The workflow fails on duplicate IDs, invalid controlled values, broken required
  links, and missing required artifacts.
- Generation produces the central navigation view and agent context deterministically.
- Generated output is clearly marked and is not treated as a manually edited source.
- No workflow prints or stores tokens, secrets, raw sensitive payloads, or private
  evidence outside its approved access boundary.

### Agent context

- The generated context can answer which work is active, blocked, recently changed,
  released, superseded, or awaiting approval.
- Each summary item links to the authoritative plan or investigation.
- The context explicitly distinguishes facts, decisions, assumptions, unknowns, and
  historical artifacts.
- A read-only agent access path is documented and tested.

### Cost and operations

- The recommendation records GitHub plan requirements, expected Action usage, and
  any hosting cost.
- The cheapest viable dashboard and generation approach is selected.
- Maintenance ownership and failure recovery are documented.
- The migration does not require a continuously running service.

## Constraints and invariants

- `docs/ecosystem-improvement-workflow.md` remains the governing lifecycle process.
- Repository ownership boundaries remain unchanged.
- Cross-repository changes follow the existing coordination protocol.
- No autonomous commit, push, branch creation, issue creation, Project mutation,
  deployment approval, or production mutation is implied by agent access.
- Documentation and identifiers remain in English according to repository policy.
- Sensitive evidence remains sanitized and excluded from Git.
- Existing release and API documentation contracts remain authoritative for runtime
  behavior.
- The migration must be reversible and must preserve historical traceability.

## Required design questions

The recommendation must answer:

1. Can the available GitHub account create and administer the required Project?
2. Should the Project be organization-level or repository-level?
3. Which Project fields and views are mandatory for the first release?
4. Is Project status the sole operational status, with generated Markdown views,
   or is a repository metadata file required during transition?
5. How are Project items and Issues linked to stable improvement IDs?
6. How will updates to Project state be reflected in the generated agent context?
7. What read-only API or CLI access will the agent use?
8. Which GitHub Actions permissions are needed, and which are explicitly forbidden?
9. Where should the generated dashboard be published, if anywhere?
10. How should historical entries without complete metadata be represented?
11. What is the pilot rollback procedure and reconciliation evidence?
12. What cost, quota, retention, and maintenance limits apply?

## Pilot scope

The first pilot should include:

- `IMP-006` — `ecosystem-http-error-baseline`;
- `IMP-007` — `cloud-run-observability-and-capacity`;
- `IMP-009` — `scheduler-oidc-hardening`.

The pilot should exercise multiple repositories, active investigations, security
work, blockers, canonical links, and different levels of technical evidence. It
must not migrate all historical entries until reconciliation succeeds.

## Required documentation and synchronization

The implementation must update, as applicable:

- this brief and its approval metadata;
- the recommendation and living plan;
- `docs/ecosystem-improvement-workflow.md` with the validated target process;
- `docs/proposals/index.md` as a generated or transition-compatible view;
- `docs/proposals/ecosystem-improvement-register.md` during the transition;
- repository documentation describing the Project, Issue, and agent access model;
- GitHub Issue and Project templates;
- GitHub Actions workflow documentation;
- generated dashboard and agent-context documentation.

## Testing expectations

The implementation must include:

- metadata schema validation;
- duplicate ID and slug detection;
- controlled status, level, type, and size validation;
- required-link and artifact checks;
- generated-output determinism checks;
- pilot Project/Issue reconciliation;
- negative tests for missing artifacts and invalid state;
- secret and sensitive-content boundary checks where practical;
- read-only agent retrieval validation;
- rollback and rerun validation.

## Cost and operational questions

The recommendation must compare:

- GitHub Project and API availability under the current account;
- GitHub Actions minutes and artifact retention;
- GitHub Pages or artifact hosting versus local/static output;
- maintenance cost of synchronization and generated context;
- the cost of Jira, Trello, or a custom GCP service;
- the cheapest viable option that still supports reliable agent retrieval.

## Exit criteria

This brief is ready for approval when the recommendation questions are explicit,
the pilot and acceptance criteria are observable, the source-of-truth boundaries
are unambiguous, and no hidden production or service-code scope remains.

Approval must be recorded explicitly before permanent GitHub Project mutation,
Issue migration, or workflow automation begins.
