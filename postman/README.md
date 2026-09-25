# Postman collection — pf ecosystem

Single Postman collection covering all `pf-*` services (pf-rates, pf-payroll, pf-db,
pf-sheets). Lives here as plain JSON so it can be edited like any other file in this
repo (by hand, by code-puppy, in a PR, whatever) and is pushed to your real Postman
workspace automatically on every push to `main` that touches it.

## How the sync works

```
edit postman/pf-ecosystem.postman_collection.json
        │
        ▼
   git push to main
        │
        ▼
.github/workflows/sync-postman.yml (triggers only on changes under postman/)
        │
        ▼
PUT https://api.getpostman.com/collections/{POSTMAN_COLLECTION_UID}
        │
        ▼
Your Postman workspace shows the updated collection -- no manual import needed.
```

This is a **one-way sync: repo → Postman.** Edits made directly in the Postman app are
**not** pulled back automatically -- if you change something in the Postman UI, export it
(`Collection → ... → Export → Collection v2.1`) and overwrite the JSON file here, or it
will get clobbered on the next push.

> Postman Team/Enterprise plans also offer a native bidirectional Git sync (no custom
> workflow needed) -- if you upgrade later, you can drop `sync-postman.yml` and use that
> instead. This setup works on **any** Postman plan, including Free.

## One-time setup

1. **Get a Postman API key**: Postman app → avatar (top right) → **Settings** →
   **API keys** → **Generate API Key**. Copy it, you won't see it again.

2. **Find your collection's UID**:
   - Easiest: open the collection in the Postman **web app** (not desktop) — the URL
     looks like `https://go.postman.co/workspace/.../collection/<UID>`.
   - Or via API, listing every collection your key can see:
     ```bash
     curl -s -H "X-Api-Key: <your-api-key>" https://api.getpostman.com/collections \
       | jq '.collections[] | {name, uid}'
     ```
   - If the collection doesn't exist in Postman yet, create it first (import
     `pf-ecosystem.postman_collection.json` once manually via
     **Import** in the Postman app), then find its UID with the command above.

3. **Add both as GitHub Secrets** in `pf-base` (Settings → Secrets and variables →
   Actions → New repository secret):

   | Secret | Value |
   |---|---|
   | `POSTMAN_API_KEY` | the key from step 1 |
   | `POSTMAN_COLLECTION_UID` | the UID from step 2 |

4. Push a change under `postman/` to `main` and check the **Actions** tab — the
   `CI / Sync Postman Collection` workflow should turn green, and the collection in
   Postman updates within a few seconds.

## Structure

- `pf-ecosystem.postman_collection.json` — the collection itself (requests, folders per
  service, example bodies). Edit this directly.
- `pf-ecosystem.postman_environment.example.json` — **template** environment (base URLs
  + placeholder API keys). Copy it to `pf-ecosystem.postman_environment.json` locally
  (git-ignored) and fill in your real local/dev API keys -- **never commit real API
  keys**, even dev ones. See the root [AGENTS.md](../AGENTS.md) PII/secrets rule.

## Adding a request

Just edit the JSON by hand, or ask code-puppy to add it (e.g. "agregá al folder
pf-payroll un POST a /payroll/import/rows con este body de ejemplo"). Keep requests
grouped in a top-level folder per service (`pf-rates`, `pf-payroll`, `pf-db`,
`pf-sheets`), matching each service's `docs/api.md`, so this collection never drifts
further from reality than those docs do.
