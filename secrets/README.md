# secrets/

Local, machine-specific credentials shared across the `pf` ecosystem's
subprojects — service account keys, one-off tokens, anything that must
never reach git history.

## Why this exists

`~/.config/<something>` works but lives outside the repo, disconnected
from the project you're actually looking at. This folder keeps secrets
physically next to the code that uses them, while `secrets/.gitignore`
guarantees **nothing** placed here (except this README and the
`.gitignore` itself) can ever be committed — not by this repo, not by any
subproject repo, no matter which directory you `cd` into first.

That `.gitignore` uses the `*` / `!.gitignore` / `!README.md` pattern:
everything is ignored by default, including files inside any subfolder you
create here. There is no allowlist to maintain — new secrets are safe by
default.

## Layout convention

One subfolder per subproject that needs local secrets:

```
secrets/
  pf-rates/
    gdrive-oauth-token.json   # Google Drive export (see pf-rates docs)
  pf-sheets/
    client_secret_<id>.apps.googleusercontent.com.json   # OAuth Desktop app Client ID (from GCP Console)
    clasprc.json                                          # clasp 3.x credentials (mirrors the CLASP_CREDENTIALS GitHub secret)
```

## Current contents

| Path | Used by | Docs |
| --- | --- | --- |
| `pf-rates/gdrive-oauth-token.json` | `POST /exchange-rates/export` (Google Drive upload) | [`pf-rates/docs/api.md`](../pf-rates/docs/api.md) |
| `pf-sheets/client_secret_*.json` | One-time `clasp login --creds` (reuses the same GCP project as `pf-rates/gdrive-oauth-token.json`, different OAuth scopes) | [`pf-sheets/docs/ci.md`](../pf-sheets/docs/ci.md) |
| `pf-sheets/clasprc.json` | Local mirror of the `CLASP_CREDENTIALS` GitHub secret, for running `clasp push`/`pull` by hand | [`pf-sheets/docs/ci.md`](../pf-sheets/docs/ci.md) |

## Rules

- Never reference an absolute path to a file in here from committed code —
  always go through an environment variable (see each subproject's `.env`).
- Treat every file here as a live credential. If one leaks, revoke it at
  the source (Google Cloud Console, etc.), don't just delete the local copy.
