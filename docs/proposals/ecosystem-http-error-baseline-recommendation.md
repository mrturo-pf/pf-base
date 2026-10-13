# Recommendation: ecosystem HTTP error baseline

Date: 2026-10-12
Status: designed
Level: M
Scope: Reusable HTTP error classification and evidence baseline for `pf-rates`, `pf-payroll`, and `pf-sheets`.
Related artifacts: [brief](ecosystem-http-error-baseline-brief.md) · [investigation](../investigations/ecosystem-http-error-baseline.md) · [plan](ecosystem-http-error-baseline-plan.md)
Approved: pending explicit owner approval
Superseded-by: none

## 1. Recommendation

Adopt a lightweight taxonomy with six classes:

1. contract;
2. client/input;
3. application/domain;
4. dependency;
5. infrastructure;
6. unknown/evidence gap.

For every investigated error, record service, route/event, timestamp, correlation
identifier when available, status, sanitized error code, dependency classification,
impact, reproduction or evidence source, owner, and next action. Store detailed
operational evidence in the owning service's operational record; keep this proposal
focused on the reusable design.

## 2. Contract boundary

The baseline must compare actual routes/OpenAPI, service API documentation,
Postman requests, and `pf-sheets` Web App interfaces before declaring a contract
failure. Existing public responses remain unchanged unless a separate API change is
approved and synchronized across implementation, docs, and Postman.

## 3. Evidence and privacy

Never record authorization headers, secret values, connection strings, full request
bodies, payslips, RUTs, salaries, or health data. Prefer metadata, stable error
codes, truncated identifiers, status/latency, revision/run IDs, and synthetic data.
Unknown is a valid classification when evidence is insufficient.

## 4. Rejected alternatives

- Treating all 5xx responses as application defects: rejected because dependency and
  infrastructure failures require different owners and remediation.
- Creating a paid centralized observability platform: rejected as unnecessary before
  a reusable baseline proves the gap and conflicts with the ecosystem cost priority.
- Normalizing every response immediately: rejected because it would be a public
  contract change rather than an evidence baseline.

## 5. Decision gate

Approve the taxonomy, evidence template, service mapping, and release checklist.
Implementation is documentation/tooling work first; any code or public contract
change requires a separate scoped proposal.
