# Recommendation: ecosystem improvement tracking migration

Date: 2026-10-12
Status: approved
Level: L
Scope: Migrate PF improvement tracking to a GitHub-centered operating model while preserving Git-based investigations, decisions, plans, and evidence.
Related artifacts: [brief](ecosystem-improvement-tracking-migration-brief.md) · [investigation](../investigations/ecosystem-improvement-tracking-migration.md) · [plan](ecosystem-improvement-tracking-migration-plan.md) · [register](ecosystem-improvement-register.md) · [workflow](../ecosystem-improvement-workflow.md)
Approved: 2026-10-12 by owner (conversation)
Superseded-by: none

## 1. Executive recommendation

Adopt a GitHub-centered hybrid model:

- GitHub Project is the operational queue for current status, priority, ownership,
  affected repositories, dependencies, and views;
- one GitHub Issue represents each improvement and provides coordination;
- Git repositories remain authoritative for investigations, briefs,
  recommendations, plans, contracts, and evidence;
- GitHub Actions validates structured metadata and generates navigation, dashboard,
  and agent-context outputs;
- the agent consumes a generated, sanitized context rather than treating a board
  description or historical proposal as the current contract.

Do not move technical evidence into the Project, create a custom GCP application,
or replace the existing workflow. This provides the requested visualization and
queryability with the smallest change to the established process.

Implementation is conditional on a read-only GitHub capability check and explicit
approval. Until then, the current Markdown index and register remain the
transition source of truth.

## 2. Alternatives considered

### Jira

Rejected as the default because it creates a separate operational system from the
repositories, increases administration and integration work, and encourages
parallel copies of status and technical context. Reconsider only if organizational
reporting, approvals, or non-GitHub stakeholders require Jira.

### Trello

Rejected as the primary system because its simple board model does not provide
sufficient structured dependency, metadata, API, and audit behavior for this
multi-repository lifecycle. It could represent a lightweight personal view but
would not be the ecosystem record.

### Custom GCP application

Rejected for the first release because it adds application, identity, hosting,
security, and maintenance work without solving a problem that GitHub Project plus
Actions cannot reasonably address. Reconsider if GitHub access or data residency
constraints make the required read-only integration impossible.

### Git-only generated dashboard

Useful as a companion and fallback, but insufficient as the sole operational
coordination surface because it lacks a practical discussion and work-item model.

## 3. Source-of-truth boundaries

| Field or concern | Authoritative source | Generated or linked views |
|---|---|---|
| Current operational status | GitHub Project | Index and agent context |
| Priority, owner, affected repositories, blockers | GitHub Project | Dashboard and agent context |
| Improvement identity and durable slug | Repository metadata and Issue | Project item and generated views |
| Investigation findings | Git investigation artifact | Issue links and agent context |
| Design decision | Git recommendation artifact | Issue links and agent context |
| Implementation progress and validation | Git plan artifact | Issue comments and agent context |
| Workflow gates | `ecosystem-improvement-workflow.md` | Documentation links |
| Runtime/API contract | Code, generated OpenAPI, API docs, Postman | Never overridden by Project |
| Historical decision | Git history and superseded artifact | Agent context with historical label |

During transition, manually maintained Markdown indexes remain compatibility views.
After the pilot and reconciliation pass, they should be generated or explicitly
marked as snapshots. No equivalent status field should be manually maintained in
both Project and Markdown.

## 4. GitHub Project design

Create one ecosystem-level Project named `PF Ecosystem Improvements`, subject to
account and organization capability verification.

Mandatory fields for the first release:

| Field | Values or format |
|---|---|
| Status | Existing controlled lifecycle statuses |
| Priority | Critical, High, Medium, Low |
| Size | S, M, L |
| Type | Existing controlled register types |
| Owner | One owning repository |
| Affected repositories | Multi-select repository names |
| Blocking scope | Existing controlled blocking scopes |
| Improvement ID | `IMP-NNN` |
| Slug | Stable kebab-case slug |
| Last verified | ISO date |
| Canonical plan | Repository URL, where applicable |

Initial views:

1. Kanban by lifecycle status;
2. active work ordered by priority;
3. blocked work grouped by blocking scope;
4. work grouped by owner and affected repository;
5. security and production-risk work;
6. recently verified and stale work;
7. released and historical work.

Avoid adding fields that are derivable from linked documents until the pilot proves
that they are needed. YAGNI applies even to dashboards; a field nobody maintains
is decorative bureaucracy.

## 5. GitHub Issue design

Use one Issue per improvement with a stable title:

```text
IMP-010 — ecosystem improvement tracking migration
```

The Issue body should contain only coordination data:

- objective and scope;
- owner and affected repositories;
- current next action;
- blockers and dependencies;
- canonical investigation, brief, recommendation, and plan links;
- acceptance and release status summary;
- explicit sensitive-data warning.

Technical evidence, raw logs, credentials, production payloads, and full design
records must not be copied into the Issue.

The Issue template must require the improvement ID, slug, Level, owner, affected
repositories, canonical artifact links, next action, and sensitive-data boundary.

## 6. Repository metadata and generated outputs

Add a small structured metadata block to formal proposal artifacts. It should not
repeat the full document. Minimum fields:

```yaml
id: IMP-010
slug: ecosystem-improvement-tracking-migration
level: L
owner: pf-base
affected:
  - pf-db
  - pf-rates
  - pf-payroll
  - pf-sheets
  - pf-common
status: investigating
priority: 8
```

The final schema must decide whether `status` and `priority` remain transition
fields or become generated snapshots of Project values. The steady-state design
should avoid two editable operational sources.

Generate:

```text
docs/generated/improvements.json
docs/generated/agent-context.md
docs/generated/agent-context.json
docs/generated/improvements-dashboard.html
```

Generated files must identify their generation time and source revision. The HTML
must be static and contain no secrets or unsanitized evidence. Publishing it can
start as a workflow artifact; public or Pages hosting requires a separate access
review.

## 7. GitHub Actions design

The first workflow should be validation-first and read-only with respect to
Project state. It should:

1. validate metadata schema and controlled values;
2. detect duplicate IDs and slugs;
3. validate required artifacts by Level;
4. validate relative and repository links;
5. detect invalid status/priority combinations;
6. generate deterministic JSON, Markdown, and HTML outputs;
7. run secret/sensitive-content checks appropriate to sanitized documentation;
8. publish artifacts only through approved workflow permissions.

Project synchronization should be a separate, explicitly authorized slice. It
must not silently overwrite status or reorder priorities. Any write workflow must
have least-privilege permissions, idempotent behavior, a dry-run mode, and an
operator-visible summary.

## 8. Agent access model

The agent should use a read-only access path to:

- the Project's operational fields;
- Issues and comments;
- generated context;
- relevant repository documents;
- recent pull requests and workflow results when authorized.

The agent must not receive production credentials, broad write tokens, or implicit
permission to mutate Project state. Creating Issues, changing Project fields,
merging code, committing, pushing, or approving deployments remain explicit user
actions unless a later workflow decision authorizes a narrowly scoped automation.

The generated context must label each item as current, historical, superseded,
blocked, or unresolved and link to the canonical artifact.

## 9. Migration and rollout sequence

1. Verify GitHub account, repository, Project, API, and permission capabilities.
2. Approve this recommendation and create the living plan.
3. Define metadata schema and templates without changing runtime code.
4. Create the Project and fields after explicit authorization.
5. Create the three pilot Issues and Project items.
6. Reconcile pilot status, links, blockers, and next actions against Git artifacts.
7. Implement validation and deterministic generation in GitHub Actions.
8. Generate the pilot dashboard and agent context.
9. Perform read-only retrieval validation and negative tests.
10. Obtain approval for historical migration and migrate remaining entries.
11. Generate or retire duplicate Markdown views only after reconciliation evidence.
12. Update the workflow with the validated steady-state process and close the plan.

A migration item is not considered released merely because its Project item exists.
The generated outputs, reconciliation, validation, and rollback evidence are part
of the release gate.

## 10. Rollback and compatibility

Rollback means:

- stop Project synchronization workflows;
- preserve Project items and their history;
- restore the last known Markdown index/register snapshot if generated output is
  incorrect;
- remove or disable generated publication, not historical Git artifacts;
- retain the stable IDs and links for a later retry;
- record the discrepancy and decision in the living plan.

The migration must never delete investigations, recommendations, plans, Issues,
Project history, or release evidence as part of normal rollback.

## 11. Testing strategy

Required tests include:

- valid and invalid metadata fixtures;
- duplicate ID and slug fixtures;
- missing investigation/brief/recommendation/plan cases by Level;
- invalid status, priority, type, size, owner, and blocker cases;
- broken local and repository-link cases;
- deterministic generation comparison;
- pilot Project-to-artifact reconciliation;
- read-only API retrieval and permission-denial behavior;
- generated context omission of secrets and sensitive evidence;
- rerun and rollback behavior.

No production mutation or runtime service test is required for this process-only
change. Any GitHub mutation must use a separately approved integration test scope.

## 12. Cost and operational impact

Expected infrastructure cost is zero or near zero if generation uses existing
GitHub Actions and workflow artifacts. GitHub plan limits, Project availability,
Actions minutes, artifact retention, and optional Pages hosting must be verified.

The cheapest viable initial publication is a workflow artifact or repository-hosted
static output. A continuously running Cloud Run dashboard is not justified for the
first release.

The recurring engineering cost is maintaining metadata schemas, validation, and
Project/API compatibility. This is lower than operating a custom GCP application
but must be assigned to `pf-base` and covered by tests.

## 13. Decision and approvals

Recommended decision: approve the GitHub-centered hybrid design after the
read-only capability check confirms that the required Project, Issue, API, and
Actions features are available under acceptable permissions and cost.

Open approvals:

- owner approval of the target architecture;
- authorization to create the Project and pilot items;
- acceptance of Project as the operational status authority;
- approval of the agent's read-only access boundary;
- approval of generated dashboard publication location;
- approval to migrate historical entries after pilot validation.

Until these approvals are recorded, status remains `designed` and implementation
must not begin.
