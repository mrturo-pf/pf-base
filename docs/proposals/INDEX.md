# PF Improvement Proposal Index

Central lifecycle index for investigations and proposal artifacts across the PF
ecosystem. The `Owner` is exactly one module/repository: the initiator that
hosts the coordination artifacts. `Affected` lists other modules involved.

Use only the controlled statuses defined in
[`docs/ecosystem-improvement-workflow.md`](../ecosystem-improvement-workflow.md).
The status meanings and metadata minimum are defined there; this index stores
only lifecycle data and notes.

| Slug | Level | Owner | Affected | Scope | Status | Notes | Authoritative artifact | Related investigation | Superseded-by | Updated |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `health-additional-uf-mismatch` | L | `pf-payroll` | `pf-rates` | Investigate and resolve UF-denominated health contribution mismatches | closed | Investigation says production issue resolved; one reference-data decision remains deliberately non-actionable | [investigation](../../modules/pf-payroll/docs/investigations/health-additional-uf-mismatch.md) | none | none | 2026-10-04 |
| `payroll-operations-endpoint-usage` | L | `pf-payroll` | `pf-base`, `pf-db`, `pf-rates`, `pf-sheets` | Verify historical and current operation endpoint consumers | closed | Current OpenAPI/docs/Postman surface reconciled; historical traffic retained as context | [investigation](../../modules/pf-payroll/docs/investigations/payroll-operations-endpoint-usage.md) | none | none | 2026-10-04 |
| `cli-removal` | L | `pf-payroll` | — | Remove obsolete CLI adapters while preserving HTTP use cases | released | Removed in `3e9acb6`; CI/deploy run `37169399930` passed | [current code](../../modules/pf-payroll/src/) + [brief](../../modules/pf-payroll/docs/proposals/cli-removal-brief.md) | [investigation](../../modules/pf-payroll/docs/investigations/cli-removal.md) | none | 2026-10-04 |
| `future-increase-ipc-extrapolation` | M | `pf-payroll` | — | Future salary projection extrapolation | released | Code paths `_extrapolate_cycle_ratio` and `_apply_ipc_step` are present; included in deployed descendant `50e7bb5`, run `37128861113` passed | [current code](../../modules/pf-payroll/src/payroll/infrastructure/db/repositories/payroll_repository_shared.py) + [recommendation](../../modules/pf-payroll/docs/proposals/future-increase-ipc-extrapolation-recommendation.md) | none | none | 2026-10-04 |
| `net-pay-prediction-reimplementation` | M | `pf-payroll` | `pf-rates` | UF-backed future net-pay prediction | released | Deployed with successful run `36933676711`; later improvements remain subject to their own release evidence | [plan](../../modules/pf-payroll/docs/proposals/net-pay-prediction-reimplementation-plan.md) | none | none | 2026-10-04 |
| `pay-period-columns-removal` | L | `pf-payroll` | `pf-db` | Remove obsolete period columns and review workflow | released | Migration and consumer implementation are historical; current code is the contract | [current code](../../modules/pf-payroll/src/) + [recommendation](../../modules/pf-payroll/docs/proposals/pay-period-columns-removal-recommendation.md) | [investigation](../../modules/pf-payroll/docs/investigations/payroll-operations-endpoint-usage.md) | none | 2026-10-04 |
| `payroll-update-delete` | L | `pf-payroll` | — | Identity-aware update and transactional delete APIs | released | Commit `7db5d3b`; CI/deployment run `37219998220` passed | [current API/OpenAPI](../../modules/pf-payroll/docs/api.md) + [recommendation](../../modules/pf-payroll/docs/proposals/payroll-update-delete-recommendation.md) | none | none | 2026-10-04 |
| `payroll-natural-key-conflict` | L | `pf-payroll` | — | Make no-ID structured imports insert-only when the natural key already exists | in progress | Implementation plan created; explicit user authorization recorded; no release yet | [plan](../../modules/pf-payroll/docs/proposals/payroll-natural-key-conflict-plan.md) + [recommendation](../../modules/pf-payroll/docs/proposals/payroll-natural-key-conflict-recommendation.md) | none | none | 2026-10-04 |
| `pdf-import` | L | `pf-payroll` | `pf-rates` | PDF preview and validate/commit import | released | Living action plan records implementation and validation | [action plan](../../modules/pf-payroll/docs/proposals/pdf-import-action-plan.md) | none | none | 2026-10-04 |
| `pdf-template-management` | L | `pf-payroll` | `pf-db` | Database-backed PDF template CRUD and normalization | released | Living plan records schema and consumer follow-ups | [plan](../../modules/pf-payroll/docs/proposals/pdf-template-management-plan.md) | none | none | 2026-10-04 |
| `pf-rates-batch-lookup` | L | `pf-payroll` | `pf-rates` | Batch exchange-rate and economic-index lookups | released | Implemented in `4ecaaa2`, coverage in `acc49da`; release/deploy run `37166988500` passed after the initial feature run failed | [plan](../../modules/pf-payroll/docs/proposals/pf-rates-batch-lookup-plan.md) | none | none | 2026-10-04 |
| `spreadsheet-export` | M | `pf-payroll` | — | CSV/XLSX export and blank template | released | Living plan records implementation corrections and live verification | [plan](../../modules/pf-payroll/docs/proposals/spreadsheet-export-plan.md) | none | none | 2026-10-04 |

## Index rules

- Add a row when a Level M or L investigation, brief, or recommendation is
  created. An investigation starts as `investigating`, even if it later closes
  as non-actionable and never produces a brief.
- Register the slug in this index at creation and update `Status` and `Updated`
  at every lifecycle transition.
- Keep `Status` machine-readable and put explanations in `Notes`.
- Keep `Owner` singular. Put every other participating module in `Affected`.
- Link all affected repositories' docs or README files through `Related
  artifacts` when they need local context.
- Record commit SHAs, workflow run IDs, and deployment status in the living plan
  or authoritative code/API documentation; summarize only the useful reference
  in `Notes`.
- Never delete superseded rows. Set `Superseded-by` to the replacement artifact.
- If an older artifact lacks reliable metadata, mark that fact in `Notes` and
  reconcile it during the next session instead of guessing.

[The workflow's Naming and status conventions](../ecosystem-improvement-workflow.md#naming-and-status-conventions) defines the controlled status list and metadata minimum for new artifacts.

The index is a navigation and lifecycle record. It does not replace the owning
repository's `AGENTS.md`, API documentation, migration documentation, OpenAPI,
or released code.
