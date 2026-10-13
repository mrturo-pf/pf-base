# Investigation: ecosystem HTTP error baseline

Date: 2026-10-12
Status: investigating
Level: M
Scope: Establish a reusable baseline and classification process for HTTP errors and contract failures across `pf-rates`, `pf-payroll`, and `pf-sheets`.
Owner: `pf-base`
Related artifacts: [brief](../proposals/ecosystem-http-error-baseline-brief.md) · [recommendation](../proposals/ecosystem-http-error-baseline-recommendation.md) · [plan](../proposals/ecosystem-http-error-baseline-plan.md)
Superseded-by: none

## 1. Question

What minimum evidence and classification rules allow the ecosystem to distinguish
application failures, contract failures, dependency failures, and infrastructure
failures without turning every HTTP error into an incident or hiding a real one?

## 2. Evidence boundary

The baseline must cover:

- FastAPI services `pf-rates` and `pf-payroll`;
- the `pf-sheets` Apps Script/Web App boundary;
- route, OpenAPI, Postman, and consumer contract mismatches;
- Cloud Run and database dependency symptoms;
- synthetic validation only unless separately approved operational evidence exists.

The baseline must not collect credentials, raw authorization headers, payslips,
RUTs, salaries, health data, or full request bodies.

## 3. Initial classification

| Class | Meaning | Required evidence |
|---|---|---|
| Contract | Route, method, schema, auth, or documented status mismatch | Request shape, route/OpenAPI/Postman comparison, sanitized response |
| Client | Invalid caller input or unsupported consumer behavior | Sanitized request metadata and stable error response |
| Application | Defect in domain or orchestration logic | Correlation ID, route, sanitized error, test/reproduction |
| Dependency | `pf-rates`, database, Secret Manager, or external provider failure | Dependency name, timeout/status, retry behavior, no secret values |
| Infrastructure | Cloud Run, networking, IAM, capacity, or deployment failure | Run/revision metadata, status, latency/capacity evidence |
| Unknown | Insufficient evidence | Explicit evidence gap and next collection step |

## 4. Open questions

- Which correlation identifier is available and safe at each service boundary?
- Which status/error fields can be normalized without changing public contracts?
- What sampling and retention are affordable under scale-to-zero operation?
- Which failures require a Postman/API contract update versus an operational alert?

## 5. Current conclusion

Create a small, reusable baseline and evidence template first. Do not introduce a
new paid observability product or silently change error responses. The baseline
must be adopted by each owning repository through its existing release and API
validation process.
