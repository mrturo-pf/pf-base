# architecture

Interactive architecture diagram of the PF ecosystem, generated with
[Archify](https://github.com/tt-a1i/archify). It's the visual companion to the
["How they relate"](../README.md#how-they-relate) section of the root README — not a
replacement for each subproject's own docs.

## Files

| File | What it is |
| --- | --- |
| `index.html` | Hand-written (not generated) landing page with clickable links to every diagram below. Open this first if you don't know where to start. |
| `base.json` | Ecosystem-wide Archify spec (source of truth): the 5 subprojects, boundaries, connections and side cards. Hand-edited. |
| `base.html` | Self-contained, generated HTML output of `base.json`. Do not edit by hand — regenerate it instead. |
| `pf-payroll.architecture.json` / `.html` | Zoomed-in spec + output of `pf-payroll`'s internal hexagonal layers, with **repository evidence** (see below). |
| `pf-rates.architecture.json` / `.html` | Same idea for `pf-rates` (single FastAPI interface, plus its rate-provider/Google Drive infrastructure adapters). |
| `pf-sheets.architecture.json` / `.html` | Same idea for `pf-sheets` — note its shape differs (see below), since it's Apps Script, not a hexagonal Python service. |
| `pf-db.architecture.json` / `.html` | Not a layered-architecture diagram — a **table-ownership** diagram: which of the 18 tables each service owns/writes, and the actual read access pattern. |
| `generate.sh` | Wraps the Archify CLI to validate/(re)deliver any of the specs above. |

## Navigating between diagrams

Archify's own schema has no `link`/`href` field on components or cards — every generated
`.html` is a deliberately self-contained artifact (that's what lets it open via `file://`
with no server). So there's no native way to click a box in the ecosystem diagram and jump
into its per-app detail diagram. Two things bridge that gap instead:

- **`index.html`** — a small hand-written (not Archify-generated) landing page with a
  clickable card per diagram. Safe to edit directly, unlike the generated `.html` files.
- **The "Want more detail?" card** on the ecosystem diagram itself lists every per-app
  diagram's filename in plain text (cards only support plain strings, not links).

## Two levels of detail, two kinds of diagram

The ecosystem diagram (`base.json`) answers *"how do the 5 subprojects relate?"* and
deliberately stays shallow — that's the right level for a system-context view. Archify
doesn't run any app or introspect live code to add more detail automatically; every extra
bit of detail has to be authored by hand, and cramming five services' internal layers
into one diagram would blow past Archify's own "~8-12 nodes, one clear story" guidance
and turn it into noise.

Instead, each subproject that needs a deeper view gets **its own spec + its own HTML**,
following the naming convention `<subproject>.architecture.json` -> `<subproject>.html`
(see `pf-payroll.architecture.json` as the reference example for a hexagonal Python
service, and `pf-sheets.architecture.json` for a differently-shaped one — it has no
application/ports layer since Apps Script has no DI, just `domain` / `infrastructure` /
three separate `interfaces` entry points). `pf-payroll` and `pf-rates` zoom into the
hexagonal layers (`interfaces -> application -> domain`, `infrastructure ->
application`) described in their own `AGENTS.md`. `pf-db` gets a different kind of
diagram entirely — see below — since it's pure DDL/migrations with no layering to zoom
into.

### Repository evidence (grounding detail in real code)

Per-app diagrams also use Archify's **repository-evidence** feature so the extra detail
isn't just hand-drawn boxes: `meta.repository` pins a GitHub URL + full commit SHA, and
each component's `sources` lists real repo-relative file paths. When you regenerate with
`--repo-root` pointing at that subproject's own git checkout (the wrapper script does this
automatically, see below), Archify verifies every path against real git blobs at that
commit — it fails closed if a reference doesn't exist, so the diagram can't silently drift
from the code it claims to describe.

To add a new per-app diagram, copy the pattern in `pf-payroll.architecture.json`: pick the
subproject's real commit SHA (`git rev-parse HEAD` inside `modules/<name>`, only after it's
pushed), reference real files per layer (no line ranges needed — whole-file references are
simpler and still verified), and run `./generate.sh <name>`.

## What's on the ecosystem diagram (`base.json`)

- **Components:** `pf-payroll` and `pf-rates` (FastAPI services), `pf-db` (Alembic
  migrations), the shared `PostgreSQL` instance, `pf-common` (shared Make targets), and
  `pf-sheets` (Apps Script macro) with its external dependency `Google Sheets/Drive`.
- **Connections:** `pf-payroll` → `pf-rates` over HTTP (exchange rates, tax brackets);
  both services → `PostgreSQL` over SQL; `pf-db` → `PostgreSQL` via `alembic upgrade
  head`; `pf-common` → `pf-payroll`/`pf-rates` via shared Make targets (dashed);
  `pf-sheets` → `pf-rates` over HTTP (triggers the export) and `pf-sheets` →
  `Google Sheets/Drive` (reads the CSV, upserts rows — dashed).
- **Cards:** runtime notes, schema ownership (who owns which tables), shared tooling,
  and the Sheets integration.

This mirrors the actual topology described in each subproject's `AGENTS.md` — if that
topology changes (new service, new dependency, table ownership moves), update
`base.json` first and regenerate, don't hand-patch the HTML.

## What's on each per-app diagram

- **`pf-payroll`:** the four hexagonal layers — `Interfaces` (FastAPI, Typer CLI, HTML
  dashboard), `Application` (use cases/services + `Protocol` ports), `Domain` (pure logic,
  zero I/O), `Infrastructure` (SQLAlchemy repositories, HTTP clients, importers/reporting)
  — plus its two externals, `PostgreSQL` and `pf-rates`.
- **`pf-rates`:** the same four layers with a single `Interfaces` component (API only),
  plus its distinctive infrastructure trio — SQLAlchemy repositories, chained rate
  providers (mindicador.cl / SII / Banco Central), and a Google Drive CSV export adapter.
- **`pf-sheets`:** three layers, no ports — `Domain` (pure functions), `Infrastructure`
  (adapters over `SpreadsheetApp`/`DriveApp`/`UrlFetchApp`/`PropertiesService`), and three
  separate `Interfaces` entry points (a human-triggered bound macro, an HTTP Web App, and
  an Apps Script Library consumed by other spreadsheets like Payroll/MedicalRefund).
- **`pf-db`:** not a layered diagram — a **table-ownership** diagram. Shows the two table
  clusters (`RAT_*`, 5 tables, owned by `pf-rates`; `PAY_*` + `PAY_MV_SUMARY`, 14, owned by
  `pf-payroll`), which service writes to which, `pf-db` as the DDL source for both, and the
  one access-pattern nuance worth diagramming: `pf-payroll` never reads `RAT_*` tables via
  direct SQL even though the DB would technically allow it — it always goes through
  `pf-rates`' HTTP API instead.

Each shares the same dashed-arrow convention: solid arrows follow the request path,
dashed arrows show an adapter *implementing* a port/contract the core depends on — the
dependency-inversion at the heart of the hexagonal pattern (where it applies).

## Viewing it

Open any `.html` file in this folder in a browser — no server needed. Each supports
pan/zoom, a light/dark theme toggle, and relationship tracing (click a component to
highlight its connections). Query params: `?theme=light|dark`, `?embed=1` (chrome-less),
`?present=1` (presentation mode).

## Regenerating after a topology change

Archify itself isn't vendored here (third-party tool). The script expects it as a
sibling checkout at `../../archify/archify/bin/archify.mjs` by default:

```bash
cd architecture
./generate.sh                    # ecosystem: base.json -> base.html
./generate.sh --open             # same, then open the result in the default browser
./generate.sh pf-payroll         # per-app: pf-payroll.architecture.json -> pf-payroll.html
./generate.sh pf-payroll --open  # same, then open the result
./generate.sh pf-rates           # same idea for pf-rates
./generate.sh pf-sheets          # same idea for pf-sheets
./generate.sh pf-db              # table-ownership diagram for pf-db
```

Per-app diagrams auto-detect their repo root as `../modules/<name>` to verify repository
evidence; override with `REPO_ROOT` if needed. If you cloned Archify elsewhere, point
`ARCHIFY_BIN` at it:

```bash
ARCHIFY_BIN=/path/to/archify/bin/archify.mjs ./generate.sh
```

Requires Node.js >= 18. `generate.sh --help`-equivalent info (including how to fetch
Archify if you don't have it yet) is documented inline in the script's header comment.
