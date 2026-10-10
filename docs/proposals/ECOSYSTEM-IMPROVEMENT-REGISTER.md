# PF Ecosystem Improvement Register

This is the cross-repository intake register for improvements discovered during
investigations, implementations, reviews, and operational work.

Its purpose is to keep unrelated findings visible without expanding the scope of
the active task. Entries are intentionally concise. Detailed evidence belongs in
a dedicated investigation or proposal only after the improvement is authorized
for separate work.

## Scope rules

- Add an entry when a valid improvement is unrelated to the active task's
  objective, acceptance criteria, or direct dependencies.
- Do not expand the active brief, recommendation, or plan with the unrelated
  improvement. Add a short cross-reference to this register instead.
- Keep each entry limited to its summary, impact, ownership, next action, and
  links to supporting evidence.
- Add `Blocked by`, `Blocks`, and `Blocking scope` whenever an entry depends on
  another workstream or prevents another change from progressing.
- Use `none` when no dependency is known. Do not infer a dependency from shared
  repositories alone.
- `Blocking scope` must identify where the dependency applies: `none`, `local
  preparation`, `migration`, `cutover`, `release`, or `incident response`.
- Keep `Resolution` current: record the outcome when an entry is `validated`,
  `released`, `superseded`, or `closed`.

## Security and sensitive findings

Security, privacy, data-loss, production-safety, and credential findings must be
registered even when they are unrelated to the active task. Registration never
replaces incident response or urgent containment: a critical finding must be
escalated immediately and handled according to the owning repository's security
rules.

Keep entries sanitized. Never include credentials, API keys, connection strings,
raw logs, production payloads, personal data, health information, salaries, or
other sensitive values. Link to an approved investigation or restricted evidence
location when more detail is required.

## Controlled fields

### Priority

`Priority` is a unique positive integer ranking across active register entries:

- `1` is the first item to take;
- larger numbers are lower in the recommended order;
- priority is populated only for active entries with status `planned`,
  `investigating`, `designed`, `approved`, `in progress`, or `blocked`;
- priority must be `—` for completed or discarded entries with status `validated`,
  `released`, `superseded`, or `closed`;
- do not reuse a number for two active entries;
- rank by urgency, blocking impact, dependency order, and risk — not by
  `Importance` alone;
- recalculate the complete active ranking whenever an entry is added, its status
  changes, a blocker changes, or the critical path changes;
- if an entry becomes inactive, remove its active priority and compact the remaining
  active ranking; preserve the former value in `Resolution` only when useful for
  historical auditability.

Priority is an execution-order recommendation, not authorization to implement.
Critical security findings still require immediate escalation even if the normal
work queue is being handled differently.

### Type

Use one primary type from this list:

```text
security | privacy | architecture | data/schema | api/contract |
reliability | performance | cost | observability | developer-experience |
tooling | documentation | testing | operations | process
```

### Importance

`Importance` describes urgency and impact, independently from estimated work:

- `critical`: immediate security, privacy, data-loss, production-safety, or
  compliance risk;
- `high`: substantial cross-repository, contract, reliability, cost, or security
  impact, but no immediate critical response is required;
- `medium`: meaningful technical debt, maintainability, performance, or process
  improvement;
- `low`: useful cleanup, documentation, ergonomics, or non-urgent refinement.

### Size

`Size` uses the ecosystem's existing planning levels:

- `S`: local change with no public contract, schema, or cross-repository impact;
- `M`: meaningful work in one repository or limited coordination;
- `L`: cross-repository work, migration, public contract, security, production
  investigation, destructive behavior, or complex rollout.

`Importance` and `Size` must not be conflated. A small urgent security fix can be
`Importance: critical` and `Size: S`.

### Status

Use the controlled lifecycle statuses from the ecosystem workflow:

```text
planned | investigating | designed | approved | in progress | blocked |
validated | released | superseded | closed
```

## Entries

| Priority | ID | Slug | Summary | Type | Importance | Size | Status | Owner | Affected | Discovered in | Blocked by | Blocks | Blocking scope | Next action | Related artifacts | Resolution | Updated |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `IMP-001` | `scheduler-credential-exposure-remediation` | Remediate the credential exposed in the Scheduler inventory, rotate/revoke it, review use, and remove exposed artifacts. | security | critical | M | investigating | `pf-payroll` | `pf-base`, `pf-payroll` | `pf-svc-income-renaming` investigation | none | pf-svc-income-renaming cutover and release | cutover/release | Complete containment and incident response. | [`gcp-scheduler-credential-exposure`](../../modules/pf-payroll/docs/investigations/gcp-scheduler-credential-exposure.md) | Complete containment, rotation/revocation, and incident response. | 2026-10-10 |
| 2 | `IMP-002` | `neon-credential-and-backup-hardening` | Harden Neon credentials, runtime access, backup retention, restore rehearsal, and handling of sensitive database dumps. | security | critical | L | investigating | `pf-db` | `pf-base`, `pf-payroll`, `pf-rates` | `pf-svc-income-renaming` plan | none | pf-svc-income-renaming schema migration and cutover | migration/cutover | Create a dedicated investigation and sanitized backup/restore standard. | [`pf-svc-income-renaming` plan](../../modules/pf-payroll/docs/proposals/pf-svc-income-renaming-plan.md) | Establish approved backup, restore, retention, and credential handling. | 2026-10-10 |
| 3 | `IMP-005` | `cloud-deployer-identity-hardening` | Separate runtime, deployer, and administration identities and evaluate Workload Identity Federation instead of long-lived deployment keys. | security | high | L | planned | `pf-common` | `pf-base`, `pf-db`, `pf-rates`, `pf-payroll` | `pf-svc-income` plan | none | pf-svc-income-renaming deployment and cutover | cutover/release | Define a reusable least-privilege deployment model. | [`pf-svc-income` plan](../../modules/pf-payroll/docs/proposals/pf-svc-income-renaming-plan.md) | Define the reusable least-privilege deployer/runtime model. | 2026-10-10 |
| 4 | `IMP-003` | `database-runtime-role-hardening` | Replace owner-level application database access with least-privilege runtime roles and explicit grants. | security | high | L | planned | `pf-db` | `pf-payroll`, `pf-rates` | `pf-svc-income-renaming` plan | none | pf-svc-income-renaming production release | release | Define and validate per-service role permissions. | [`pf-svc-income-renaming` plan](../../modules/pf-payroll/docs/proposals/pf-svc-income-renaming-plan.md) | Define and validate per-service least-privilege database roles. | 2026-10-10 |
| 5 | `IMP-008` | `database-identifier-length-policy` | Decide and implement the ecosystem policy for table and materialized-view identifier lengths beyond the current `pf-db` convention. | data/schema | medium | M | designed | `pf-db` | `pf-base`, `pf-payroll` | `pf-svc-income` recommendation | none | pf-svc-income-renaming physical schema migration | migration | Update `pf-db` documentation and validators before treating the new limit as active. | [`pf-svc-income` recommendation](../../modules/pf-payroll/docs/proposals/pf-svc-income-renaming-recommendation.md) | Update pf-db documentation and validators before activating the new limit. | 2026-10-10 |
| 6 | `IMP-004` | `pf-rates-database-secret-access-review` | Verify whether `pf-rates` needs `PF_DATABASE_URL` and remove unnecessary secret access. | security | high | M | investigating | `pf-rates` | `pf-db`, `pf-rates` | `pf-svc-income-renaming` investigation | none | pf-svc-income-renaming cutover if shared-secret access is required | release | Confirm actual runtime dependencies and reduce access if unnecessary. | [`pf-svc-income-renaming` investigation](../../modules/pf-payroll/docs/investigations/pf-svc-income-renaming.md) | Confirm runtime dependency and remove unnecessary access if applicable. | 2026-10-10 |
| 7 | `IMP-006` | `ecosystem-http-error-baseline` | Establish a reusable baseline and classification process for observed HTTP errors and contract failures. | observability | high | M | investigating | `pf-base` | `pf-rates`, `pf-payroll`, `pf-sheets` | `pf-svc-income` investigation | none | pf-svc-income-renaming release validation | release | Define error categories, evidence requirements, and monitoring outputs. | [`pf-svc-income` investigation](../../modules/pf-payroll/docs/investigations/pf-svc-income-renaming.md) | Define error categories, evidence requirements, and monitoring outputs. | 2026-10-10 |
| 8 | `IMP-007` | `cloud-run-observability-and-capacity` | Standardize Cloud Run alerts, dashboards, probes, scaling limits, concurrency, and database connection-budget validation. | reliability | high | M | planned | `pf-common` | `pf-db`, `pf-rates`, `pf-payroll` | `pf-svc-income` plan | none | pf-svc-income-renaming release validation | release | Define the cheapest viable operational baseline. | [`pf-svc-income` plan](../../modules/pf-payroll/docs/proposals/pf-svc-income-renaming-plan.md) | Define the cheapest viable Cloud Run operational baseline. | 2026-10-10 |


## Promotion workflow

When an entry receives explicit authorization:

1. Confirm its owner, affected repositories, type, importance, and size.
2. Create a stable proposal slug if the work is Level M or L.
3. Create the applicable investigation, brief, recommendation, and plan.
4. Add the formal M/L work to [`INDEX.md`](INDEX.md).
5. Link the formal artifacts from this register entry.
6. Update the entry status as the promoted work advances.

The original active task should retain only a short reference such as:

```markdown
Out-of-scope follow-up: registered as `IMP-003`; not required for this change.
```

## Entry template

Copy this template when adding a new item to the table:

```text
Priority: <unique active positive integer; 1 is highest, or `—` when inactive>
ID: IMP-XXX
Slug: <stable-slug>
Summary: <one or two sentences; sanitized>
Type: <controlled type>
Importance: <critical|high|medium|low>
Size: <S|M|L>
Status: planned
Owner: <repository>
Affected: <repositories>
Discovered in: <artifact path and section>
Blocked by: <IDs or none>
Blocks: <IDs, task slug, or none>
Blocking scope: <none|local preparation|migration|cutover|release|incident response>
Next action: <smallest useful next step>
Related artifacts: <links or none>
Resolution: <pending or concise outcome>
Updated: YYYY-MM-DD
```
