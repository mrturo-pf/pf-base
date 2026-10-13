# Generated PF Improvement Context

> Generated from `docs/proposals/improvements.json`. Do not edit manually.

- Schema version: `1`
- Items: `4`

## Current queue

### IMP-006 — ecosystem-http-error-baseline

- Status: `in progress` / Project `In Progress`
- Priority: `high` (5)
- Level: `M`; type: `observability`
- Owner: `pf-base`
- Affected: `pf-rates`, `pf-payroll`, `pf-sheets`
- Next action: Define error categories, evidence requirements, and monitoring outputs.
- Plan: https://github.com/mrturo-pf/pf-base/blob/main/docs/proposals/ecosystem-http-error-baseline-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/1

### IMP-007 — cloud-run-observability-and-capacity

- Status: `in progress` / Project `In Progress`
- Priority: `high` (6)
- Level: `M`; type: `reliability`
- Owner: `pf-common`
- Affected: `pf-db`, `pf-rates`, `pf-payroll`
- Next action: Define the cheapest viable operational baseline.
- Plan: https://github.com/mrturo-pf/pf-common/blob/main/docs/proposals/cloud-run-observability-and-capacity-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/2

### IMP-009 — scheduler-oidc-hardening

- Status: `in progress` / Project `In Progress`
- Priority: `high` (7)
- Level: `M`; type: `security`
- Owner: `pf-payroll`
- Affected: `pf-base`, `gcp-scheduler-runner`
- Next action: Create a separate OIDC design only when explicitly authorized.
- Plan: https://github.com/mrturo-pf/pf-payroll/blob/main/docs/proposals/scheduler-oidc-hardening-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/3

### IMP-010 — ecosystem-improvement-tracking-migration

- Status: `in progress` / Project `In Progress`
- Priority: `high` (8)
- Level: `L`; type: `process`
- Owner: `pf-base`
- Affected: `pf-base`, `pf-db`, `pf-rates`, `pf-payroll`, `pf-sheets`, `pf-common`
- Next action: Validate generated context and repository automation before historical migration.
- Plan: https://github.com/mrturo-pf/pf-base/blob/main/docs/proposals/ecosystem-improvement-tracking-migration-plan.md
- Issue: https://github.com/mrturo-pf/pf-base/issues/4
