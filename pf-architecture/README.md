# pf-architecture

Interactive architecture diagram of the PF ecosystem, generated with
[Archify](https://github.com/tt-a1i/archify). It's the visual companion to the
["How they relate"](../README.md#how-they-relate) section of the root README — not a
replacement for each subproject's own docs.

## Files

| File | What it is |
| --- | --- |
| `diagram.json` | Archify spec (source of truth): components, boundaries, connections and side cards. Hand-edited. |
| `diagram.html` | Self-contained, generated HTML output. Do not edit by hand — regenerate it instead. |
| `generate.sh` | Wraps the Archify CLI to validate `diagram.json` and (re)deliver `diagram.html`. |

## What's on the diagram

- **Components:** `pf-payroll` and `pf-rates` (FastAPI services), `pf-db` (Alembic
  migrations), the shared `PostgreSQL` instance, and `pf-common` (shared Make targets).
- **Connections:** `pf-payroll` → `pf-rates` over HTTP (exchange rates, tax brackets);
  both services → `PostgreSQL` over SQL; `pf-db` → `PostgreSQL` via `alembic upgrade
  head`; `pf-common` → `pf-payroll`/`pf-rates` via shared Make targets (dashed).
- **Cards:** runtime notes, schema ownership (who owns which tables), and shared tooling.

This mirrors the actual topology described in each subproject's `AGENTS.md` — if that
topology changes (new service, new dependency, table ownership moves), update
`diagram.json` first and regenerate, don't hand-patch the HTML.

## Viewing it

Just open `diagram.html` in a browser — no server needed. It supports pan/zoom, a
light/dark theme toggle, and relationship tracing (click a component to highlight its
connections). Query params: `?theme=light|dark`, `?embed=1` (chrome-less), `?present=1`
(presentation mode).

## Regenerating after a topology change

Archify itself isn't vendored here (third-party tool). The script expects it as a
sibling checkout at `../../archify/archify/bin/archify.mjs` by default:

```bash
cd pf-architecture
./generate.sh          # validate diagram.json + rebuild diagram.html
./generate.sh --open   # same, then open the result in the default browser
```

If you cloned Archify elsewhere, point `ARCHIFY_BIN` at it:

```bash
ARCHIFY_BIN=/path/to/archify/bin/archify.mjs ./generate.sh
```

Requires Node.js >= 18. `generate.sh --help`-equivalent info (including how to fetch
Archify if you don't have it yet) is documented inline in the script's header comment.
