# Investigation: ecosystem improvement tracking migration

Date: 2026-10-12
Status: closed
Level: L
Scope: Evaluate and prepare the migration of PF improvement tracking from manually maintained Markdown indexes and distributed proposal documents to GitHub Projects, GitHub Issues, Git repositories, GitHub Actions, and generated agent context.
Owner: `pf-base`
Related artifacts: [brief](../proposals/ecosystem-improvement-tracking-migration-brief.md) · [recommendation](../proposals/ecosystem-improvement-tracking-migration-recommendation.md) · [plan](../proposals/ecosystem-improvement-tracking-migration-plan.md) · [index](../proposals/index.md) · [workflow](../ecosystem-improvement-workflow.md)
Approved: pending explicit owner approval
Superseded-by: none

## 1. Question

How can the PF ecosystem gain a visual, queryable, and agent-accessible improvement
tracking system without losing the versioned investigations, design decisions,
living plans, release evidence, security boundaries, or repository ownership rules
already defined by the ecosystem workflow?

## 2. Current state

The current process uses:

- `docs/ecosystem-improvement-workflow.md` for lifecycle gates, artifact
  responsibilities, controlled statuses, and definition of done;
- `docs/proposals/index.md` for navigation and canonical artifact references;
- GitHub Issues and the `PF Ecosystem Improvements` Project for intake, coordination,
  current status, priority, blockers, and execution order;
- repository and module `docs/` directories for investigations, briefs,
  recommendations, plans, API contracts, deployment evidence, and operational
  documentation.

The process is durable as a technical and audit trail. Operational state is now
visualized and queried in GitHub Project/Issues; the agent should query those
sources instead of discovering current state by following Markdown tables.

## 3. Desired target

The target operating model is:

| Concern | Proposed system |
|---|---|
| Operational status, priority, owner, blockers, and views | GitHub Project |
| Improvement-level discussion and coordination | GitHub Issue |
| Investigation, decisions, plans, and evidence | Git repositories |
| Metadata and consistency validation | GitHub Actions |
| Generated navigation and dashboard | GitHub Actions output, initially static |
| Agent-oriented summary | Generated `agent-context` files |
| Process governance and lifecycle gates | `docs/ecosystem-improvement-workflow.md` |

The migration must preserve the current workflow rather than create a parallel,
less auditable process.

## 4. Facts, inferences, and assumptions

### Facts

- The root repository already defines controlled lifecycle statuses and Level M/L
  artifact requirements.
- The ecosystem has a central index plus GitHub Issues and Project for intake and coordination.
- The ecosystem spans independent repositories with explicit ownership boundaries.
- The current documentation contains active, released, superseded, and closed work.
- Sensitive evidence must remain sanitized and outside version control when raw.

### Inferences

- GitHub is a natural integration point because code, issues, pull requests,
  Actions, and project items can be linked to the same repository ecosystem.
- A visual board alone will not preserve technical evidence; Git remains required.
- Generated views are preferable to manually maintaining equivalent status tables in
  multiple places.
- A pilot is safer than a full historical migration because the current corpus has
  different artifact completeness and lifecycle states.

### Assumptions to verify

- The GitHub account and repositories support the required Projects features and
  API access.
- The owner can create or administer an organization-level Project and configure
  read/write permissions appropriate to the migration.
- The agent's authorized execution environment can read Project and Issue data
  without exposing secrets or sensitive repository content.
- GitHub Actions minutes and artifact/static-page hosting remain within the
  project's cost and access constraints.

## 5. Scope boundary

### In scope

- A common improvement identity and metadata model;
- mapping the existing workflow to GitHub Project, Issue, and repository artifacts;
- status, priority, owner, affected repository, dependency, and canonical-link
  conventions;
- validation and synchronization automation;
- generated index, dashboard, and agent context;
- pilot migration and reconciliation procedure;
- permissions, auditability, rollback, and operational cost evaluation.

### Out of scope

- Rewriting historical investigations or design decisions without evidence;
- moving technical evidence out of Git repositories;
- changing service APIs, schemas, deployment architecture, or runtime behavior;
- collecting production payloads, credentials, personal data, or raw sensitive
  operational evidence;
- granting the agent mutation authority over production or repository history;
- replacing the existing lifecycle workflow before the target process is validated.

## 6. Initial option assessment

| Option | Benefits | Risks or limitations | Initial assessment |
|---|---|---|---|
| GitHub Project plus Git | Close to code and PRs; structured views; API-accessible; low migration distance | Requires GitHub permissions and synchronization design | Preferred candidate |
| Jira plus Git | Mature workflows, dependencies, and reporting | Separate system, higher administration, duplicate links and context | Consider only if organizational reporting requires it |
| Trello plus Git | Simple visual board and low setup cost | Weak structured metadata, dependency handling, and agent-oriented querying | Insufficient as the primary system |
| Custom GCP application | Full control and GCP integration | New application to build, secure, operate, and maintain | Defer unless GitHub access is inadequate |
| Git-only generated dashboard | Maximum versionability and low infrastructure cost | Less interactive operational workflow and weaker discussion model | Useful companion, not sufficient alone |

This is an initial assessment, not a final recommendation. The recommendation
must verify platform capabilities and access before implementation.

## 7. Risks and controls

| Risk | Control |
|---|---|
| Project and Markdown status diverge | Define one operational status source and generate the other views |
| Migration loses historical context | Preserve existing artifacts and add stable IDs and links |
| Agent reads stale or superseded decisions | Generate context with current status, canonical artifacts, and superseded links |
| GitHub permissions expose sensitive data | Use least privilege, private repositories, sanitized artifacts, and read-only agent access where possible |
| Automation mutates project state unexpectedly | Start read-only, validate in a pilot, require explicit mutation boundaries |
| Historical entries do not meet new metadata rules | Mark gaps explicitly; do not infer missing ownership, approval, or release evidence |
| Dashboard becomes another manually maintained source | Generate it from structured metadata and Project/API data |
| Migration expands into a new project-management product | Keep the first release limited to tracking, validation, navigation, and context generation |

## 8. Required decisions for the recommendation

- Whether GitHub Projects is available at the required account or organization
  scope;
- which system is authoritative for current operational status;
- whether status changes are manual Project changes, Issue-driven, or generated
  from repository metadata;
- minimum metadata required in documents and Issues;
- Project fields, views, labels, and naming conventions;
- agent access method and read-only boundary;
- dashboard hosting and retention approach;
- migration treatment for released, superseded, closed, and incomplete entries;
- rollback procedure if the pilot produces inconsistent state;
- cost and maintenance expectations.

## 9. Evidence still required

The next investigation slice should inspect the actual GitHub account/repository
capabilities through an authorized, read-only workflow. It should record only
metadata such as repository visibility, Project availability, relevant API
capabilities, and permission outcomes. It must not collect tokens, secret values,
raw issue payloads containing sensitive data, or production evidence.

The repository-side slice should also inventory the current index/register rows and
proposal metadata without rewriting their historical content.

## 10. Provisional conclusion

Proceed with a formal recommendation for a GitHub-centered hybrid model:
GitHub Project for operational state, Issues for coordination, Git for durable
technical records, GitHub Actions for validation and generated views, and a
sanitized generated agent context for repeatable model retrieval.

Do not create permanent automation, migrate all historical items, or retire the
current Markdown indexes until the GitHub capability check, metadata design,
pilot, reconciliation, and rollback criteria are approved.

## 11. Exit criteria

This investigation can close when:

- the GitHub capability and permission questions are answered;
- the target source-of-truth boundaries are explicit;
- the minimum metadata and migration treatment are defined;
- risks and rollback are accepted or mitigated;
- the brief and recommendation can be written without unresolved architectural
  ambiguity;
- the pilot scope and observable acceptance criteria are agreed.
