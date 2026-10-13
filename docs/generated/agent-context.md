# Generated PF Improvement Context

> Generated from `docs/proposals/improvements.json`. Do not edit manually.

- Schema version: `1`
- Items: `25`

## Improvement references

Current status, priority, and progress are authoritative in the GitHub Project.
Query the Project before making planning decisions; this generated file stores no task state.

### HIST-007 — pf-svc-income-renaming

- Level: `L`; type: `unclassified`
- Owner: `pf-base`
- Affected: `pf-svc-income`, `pf-db`, `pf-common`, `pf-rates`, `pf-sheets`
- Next action: Recommendation approved 2026-10-05; implementation still blocked on live inventory, package-boundary details, migration locking strategy, and rollback exit evidence
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/proposals/pf-svc-income-renaming-recommendation.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/11

### HIST-008 — gcp-scheduler-credential-exposure

- Level: `L`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: none
- Next action: Investigation and remediation evidence closed; follow-up OIDC hardening is tracked separately as IMP-009
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/investigations/gcp-scheduler-credential-exposure.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/12

### HIST-009 — employers-contracts-maintenance

- Level: `L`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: `pf-db`
- Next action: Code, migration, tests, API contract, and production deployment evidence completed
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/proposals/employers-contracts-maintenance-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/13

### HIST-010 — health-additional-uf-mismatch

- Level: `L`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: `pf-rates`
- Next action: Investigation says production issue resolved; one reference-data decision remains deliberately non-actionable
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/investigations/health-additional-uf-mismatch.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/14

### HIST-011 — payroll-operations-endpoint-usage

- Level: `L`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: `pf-base`, `pf-db`, `pf-rates`, `pf-sheets`
- Next action: Current OpenAPI/docs/Postman surface reconciled; historical traffic retained as context
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/investigations/payroll-operations-endpoint-usage.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/15

### HIST-012 — cli-removal

- Level: `L`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: none
- Next action: Removed in `3e9acb6`; CI/deploy run `37169399930` passed
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/src/
- Issue: https://github.com/mrturo-pf/pf-base/issues/16

### HIST-013 — future-increase-ipc-extrapolation

- Level: `M`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: none
- Next action: Code paths `_extrapolate_cycle_ratio` and `_apply_ipc_step` are present; included in deployed descendant `50e7bb5`, run `37128861113` passed
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/src/payroll/infrastructure/db/repositories/payroll_repository_shared.py
- Issue: https://github.com/mrturo-pf/pf-base/issues/17

### HIST-014 — net-pay-prediction-reimplementation

- Level: `M`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: `pf-rates`
- Next action: Deployed with successful run `36933676711`; later improvements remain subject to their own release evidence
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/proposals/net-pay-prediction-reimplementation-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/18

### HIST-015 — pay-period-columns-removal

- Level: `L`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: `pf-db`
- Next action: Migration and consumer implementation are historical; current code is the contract
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/src/
- Issue: https://github.com/mrturo-pf/pf-base/issues/19

### HIST-016 — payroll-update-delete

- Level: `L`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: none
- Next action: Commit `7db5d3b`; CI/deployment run `37219998220` passed
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/api.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/20

### HIST-017 — payroll-natural-key-conflict

- Level: `L`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: none
- Next action: Implementation, tests, API docs, Postman, CI and deployment evidence completed
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/proposals/payroll-natural-key-conflict-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/21

### HIST-018 — pdf-import

- Level: `L`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: `pf-rates`
- Next action: Living action plan records implementation and validation
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/proposals/pdf-import-action-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/22

### HIST-019 — pdf-template-management

- Level: `L`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: `pf-db`
- Next action: Living plan records schema and consumer follow-ups
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/proposals/pdf-template-management-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/23

### HIST-020 — pf-rates-batch-lookup

- Level: `L`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: `pf-rates`
- Next action: Implemented in `4ecaaa2`, coverage in `acc49da`; release/deploy run `37166988500` passed after the initial feature run failed
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/proposals/pf-rates-batch-lookup-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/24

### HIST-021 — spreadsheet-export

- Level: `M`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: none
- Next action: Living plan records implementation corrections and live verification
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/proposals/spreadsheet-export-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/25

### IMP-001 — scheduler-credential-exposure-remediation

- Level: `L`; type: `unclassified`
- Owner: `pf-payroll`
- Affected: `pf-base`
- Next action: Credential remediation and validation completed; residual historical log limitation accepted; OIDC remains separate
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/proposals/scheduler-credential-exposure-remediation-recommendation.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/5

### IMP-002 — neon-credential-and-backup-hardening

- Level: `L`; type: `unclassified`
- Owner: `pf-db`
- Affected: `pf-base`, `pf-payroll`, `pf-rates`
- Next action: Backup/restore, dump/credential cleanup, ownership migration, and runtime cutover complete; provider-managed role residual risk accepted
- Plan: https://github.com/mrturo-pf/pf-db/blob/main/docs/proposals/neon-credential-and-backup-hardening-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/10

### IMP-003 — database-runtime-role-hardening

- Level: `L`; type: `unclassified`
- Owner: `pf-db`
- Affected: `pf-payroll`, `pf-rates`, `pf-base`
- Next action: Superseded by IMP-002, which implemented and evidenced the role hardening; retained for historical traceability
- Plan: https://github.com/mrturo-pf/pf-db/blob/main/docs/proposals/database-runtime-role-hardening-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/7

### IMP-004 — pf-rates-database-secret-access-review

- Level: `M`; type: `unclassified`
- Owner: `pf-rates`
- Affected: `pf-db`, `pf-rates`, `pf-base`
- Next action: Scoped IAM mutation complete and verified; post-mutation health and authenticated read passed
- Plan: https://github.com/mrturo-pf/pf-rates/blob/main/docs/proposals/pf-rates-database-secret-access-review-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/8

### IMP-005 — cloud-deployer-identity-hardening

- Level: `L`; type: `unclassified`
- Owner: `pf-common`
- Affected: `pf-base`, `pf-db`, `pf-rates`, `pf-payroll`
- Next action: WIF production deployments and smoke tests passed; legacy keys/grants removed; cleanup evidence recorded
- Plan: https://github.com/mrturo-pf/pf-common/blob/main/docs/proposals/cloud-deployer-identity-hardening-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/6

### IMP-006 — ecosystem-http-error-baseline

- Level: `M`; type: `observability`
- Owner: `pf-base`
- Affected: `pf-rates`, `pf-payroll`, `pf-sheets`
- Next action: Define error categories, evidence requirements, and monitoring outputs.
- Plan: https://github.com/mrturo-pf/pf-base/blob/main/docs/proposals/ecosystem-http-error-baseline-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/1

### IMP-007 — cloud-run-observability-and-capacity

- Level: `M`; type: `reliability`
- Owner: `pf-common`
- Affected: `pf-db`, `pf-rates`, `pf-payroll`
- Next action: Define the cheapest viable operational baseline.
- Plan: https://github.com/mrturo-pf/pf-common/blob/main/docs/proposals/cloud-run-observability-and-capacity-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/2

### IMP-008 — database-identifier-length-policy

- Level: `M`; type: `unclassified`
- Owner: `pf-db`
- Affected: `pf-base`, `pf-payroll`
- Next action: Policy and validator complete; local quality validation passed; commit/push/CI evidence pending; physical rename migration delegated
- Plan: https://github.com/mrturo-pf/pf-db/blob/main/docs/proposals/database-identifier-length-policy-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/9

### IMP-009 — scheduler-oidc-hardening

- Level: `M`; type: `security`
- Owner: `pf-payroll`
- Affected: `pf-base`, `gcp-scheduler-runner`
- Next action: Create a separate OIDC design only when explicitly authorized.
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/proposals/scheduler-oidc-hardening-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/3

### IMP-010 — ecosystem-improvement-tracking-migration

- Level: `L`; type: `process`
- Owner: `pf-base`
- Affected: `pf-base`, `pf-db`, `pf-rates`, `pf-payroll`, `pf-sheets`, `pf-common`
- Next action: Validate generated context and repository automation before historical migration.
- Plan: https://github.com/mrturo-pf/pf-base/blob/main/docs/proposals/ecosystem-improvement-tracking-migration-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/4
