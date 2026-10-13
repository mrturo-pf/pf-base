# Brief: ecosystem HTTP error baseline

Date: 2026-10-12
Status: investigating
Level: M
Scope: Reusable HTTP error classification and evidence baseline for `pf-rates`, `pf-payroll`, and `pf-sheets`.
Related artifacts: [investigation](../investigations/ecosystem-http-error-baseline.md) · [recommendation](ecosystem-http-error-baseline-recommendation.md) · [plan](ecosystem-http-error-baseline-plan.md)
Approved: pending explicit owner approval
Superseded-by: none

## Objective

Define a cheap, repeatable way to classify HTTP errors and contract failures,
collect enough sanitized evidence to resolve them, and distinguish release gates
from operational follow-up.

## Non-objectives

- Replacing service-specific error contracts;
- introducing paid monitoring or always-on infrastructure;
- collecting sensitive payloads or credentials;
- changing routes, status codes, or authentication without a separate contract change;
- treating every 4xx or 5xx as a production incident.

## Required outcomes

- Shared error taxonomy and evidence template;
- service-specific mapping for FastAPI and Apps Script boundaries;
- contract comparison procedure using routes, OpenAPI, docs, and Postman;
- operational classification for database, rates, IAM, Cloud Run, and timeout failures;
- release acceptance checklist with synthetic examples and explicit unknowns.

## Acceptance criteria

1. Each category has a definition, owner, minimum evidence, and next action.
2. Evidence is sanitized and contains no secrets or personal/financial data.
3. The procedure works for both Python HTTP services and `pf-sheets` Web App calls.
4. The baseline can be run with existing tooling and scale-to-zero constraints.
5. Adoption does not silently alter existing public error responses.
