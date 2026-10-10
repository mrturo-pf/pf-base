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
- Do not duplicate implementation details between this register and a formal
  proposal.
- When the user authorizes the improvement, promote it to the normal proposal
  lifecycle and link the resulting artifacts from this entry.
- A register entry does not authorize implementation, deployment, secret
  rotation, database mutation, or any other operational action.

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

| ID | Slug | Summary | Type | Importance | Size | Status | Owner | Affected | Discovered in | Next action | Related artifacts | Updated |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

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
Next action: <smallest useful next step>
Related artifacts: <links or none>
Updated: YYYY-MM-DD
```
