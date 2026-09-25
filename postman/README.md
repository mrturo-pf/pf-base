# Postman collection — pf ecosystem

Single Postman collection covering all `pf-*` services with an HTTP surface (pf-rates,
pf-payroll, pf-sheets — `pf-db` has no HTTP API, it's DDL/migrations only), plus two
environments (`LOCAL`, `GCP`). Everything lives here as plain JSON so it can be edited
like any other file in this repo (by hand, by code-puppy, in a PR) and is pushed to your
real Postman workspace automatically on every push to `main` that touches it.

## How the sync works

```
edit postman/pf-ecosystem.postman_collection.json
  or postman/pf-ecosystem.postman_environment.{local,gcp}.json
        │
        ▼
   git push to main
        │
        ▼
.github/workflows/sync-postman.yml
  ├─ sync-collection      → PUT .../collections/{POSTMAN_COLLECTION_UID}
  └─ sync-environments    → PUT .../environments/{POSTMAN_ENV_UID_LOCAL|GCP}
        │                    (api-key values injected from GitHub Secrets
        │                     right before the PUT -- see "Secrets" below)
        ▼
Your Postman workspace shows the update -- no manual import needed.
```

This is a **one-way sync: repo → Postman.** Edits made directly in the Postman app are
**not** pulled back automatically -- if you change something in the Postman UI (other
than an api-key value, see below), export it and overwrite the matching JSON file here,
or it gets clobbered on the next push.

> Postman Team/Enterprise plans also offer a native bidirectional Git sync (no custom
> workflow needed) -- if you upgrade later, you can drop `sync-postman.yml` and use that
> instead. This setup works on **any** Postman plan, including Free.

## Environments: LOCAL vs GCP

Both environments share the same four variable names (matching the collection's
requests): `pf-rates-url`, `pf-rates-api-key`, `pf-payroll-url`, `pf-payroll-api-key`.
Whichever environment is active in the Postman UI overrides the collection's own
(harmless localhost) defaults, so switching target just means picking a different
environment from the dropdown -- no request needs editing.

| | `pf-ecosystem.postman_environment.local.json` | `pf-ecosystem.postman_environment.gcp.json` |
|---|---|---|
| `*-url` values | `http://localhost:8001` / `:8000` | real Cloud Run URLs |
| `*-api-key` values in the committed file | always `""` | always `""` |
| Real key comes from | GitHub Secret `PF_RATES_API_KEY_LOCAL` / `PF_PAYROLL_API_KEY_LOCAL` | GitHub Secret `PF_RATES_API_KEY_GCP` / `PF_PAYROLL_API_KEY_GCP` |

**Why the api-key fields are always empty in git:** a Postman `"type": "secret"` variable
only *masks* the value in the UI -- the raw value is still plain text in the exported
JSON. Committing a real key (even a local dev one) would put it in git history forever.
Instead, the real values live only as GitHub Secrets and get injected into a throwaway
copy of the file inside the GitHub Actions runner, by variable key name (via `jq`,
never blind text substitution), right before the `PUT` to Postman -- then that copy is
deleted. The repo itself never sees a real key.

Practical effect: editing `*-url` values here and pushing updates Postman immediately.
Editing an `*-api-key` value here does **nothing** (it always gets overwritten with the
GitHub Secret's value on sync) -- to rotate a key, update the GitHub Secret instead
(`gh secret set PF_RATES_API_KEY_GCP --repo mrturo-pf/pf-base`) and re-run the workflow
(push any change under `postman/`, or `gh workflow run "CI / Sync Postman Collection"`).

## One-time setup

1. **Get a Postman API key**: go to
   [`https://web.postman.co/settings/me/api-keys`](https://web.postman.co/settings/me/api-keys)
   (the UI hides this outside of general Settings) → **Generate API Key**. Copy it, you
   won't see it again.

2. **Find the collection's and each environment's UID**: open it in the Postman **web
   app** (not desktop) — the URL looks like
   `https://<workspace>.postman.co/workspace/.../collection/<UID>` or `.../environment/<UID>`.
   If something doesn't exist in Postman yet, create it first (**Import** in the Postman
   app using the matching JSON here), then read its UID off the URL.

3. **Add every secret** in `pf-base` (Settings → Secrets and variables → Actions →
   New repository secret):

   | Secret | Value |
   |---|---|
   | `POSTMAN_API_KEY` | from step 1 |
   | `POSTMAN_COLLECTION_UID` | the collection's UID |
   | `POSTMAN_ENV_UID_LOCAL` | the `LOCAL` environment's UID |
   | `POSTMAN_ENV_UID_GCP` | the `GCP` environment's UID |
   | `PF_RATES_API_KEY_LOCAL` | pf-rates dev API key (from `modules/pf-rates/.env`) |
   | `PF_PAYROLL_API_KEY_LOCAL` | pf-payroll dev API key (from `modules/pf-payroll/.env`) |
   | `PF_RATES_API_KEY_GCP` | pf-rates production API key (GCP Secret Manager, secret `PF_RATES_API_KEY`) |
   | `PF_PAYROLL_API_KEY_GCP` | pf-payroll production API key (GCP Secret Manager, secret `PF_PAYROLL_API_KEY`) |

   Prefer piping values into `gh secret set` over pasting them anywhere they'd be
   echoed/logged, e.g.:
   ```bash
   grep '^PF_RATES_API_KEY=' modules/pf-rates/.env | cut -d'=' -f2- \
     | gh secret set PF_RATES_API_KEY_LOCAL --repo mrturo-pf/pf-base
   ```
   Production values living in GCP Secret Manager may be blocked from direct CLI access
   by VPC Service Controls, depending on org policy -- fetch them via the GCP Console
   or an already-authorized path instead if `gcloud secrets versions access` is denied.

4. Push a change under `postman/` to `main` (or `gh workflow run "CI / Sync Postman
   Collection" --repo mrturo-pf/pf-base`) and check the **Actions** tab — both jobs
   (`sync-collection`, `sync-environments`) should turn green.

## Structure

- `pf-ecosystem.postman_collection.json` — the collection itself (requests, folders per
  service, example bodies). Edit this directly.
- `pf-ecosystem.postman_environment.local.json` / `.gcp.json` — the two environments.
  Edit `*-url` values freely; `*-api-key` values are always overwritten at sync time
  (see above).

## Adding a request

Just edit the JSON by hand, or ask code-puppy to add it (e.g. "agregá al folder
pf-payroll un POST a /payroll/import/rows con este body de ejemplo"). Keep requests
grouped in a top-level folder per service (`pf-rates`, `pf-payroll`, `pf-sheets`),
matching each service's `docs/api.md`, so this collection never drifts further from
reality than those docs do.
