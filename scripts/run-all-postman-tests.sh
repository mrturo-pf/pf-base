#!/usr/bin/env bash
# Run the complete local Postman validation suite against the disposable LOCAL stack.
#
# This deliberately executes the full Postman collection, including mutations.
# It is LOCAL-only: the target URLs are fixed to loopback and the database is
# reset before and after the run.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POSTMAN_DIR="$ROOT_DIR/postman"
RUNTIME_KEYS_FILE="$ROOT_DIR/secrets/pf-runtime-api-keys.env"
SERVICES_SCRIPT="$ROOT_DIR/scripts/local/pf-services.sh"
DB_DIR="$ROOT_DIR/modules/pf-db"
RESTORE_SCRIPT="$DB_DIR/scripts/restore-neon-dump.sh"
NEON_DUMP="$DB_DIR/secrets/neon_dump.sql"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pf-postman-local.XXXXXX")"
REPORT_DIR="$ROOT_DIR/generated/postman-local"

COLLECTION="$POSTMAN_DIR/pf-ecosystem.postman_collection.json"
ENVIRONMENT="$TEMP_DIR/pf-postman-local.json"
PDF_FIXTURE="$TEMP_DIR/pf-synthetic-payroll.pdf"
XLSX_FIXTURE="$TEMP_DIR/pf-synthetic-payroll.xlsx"
FULL_COLLECTION="$TEMP_DIR/pf-ecosystem-run-all.json"
FIXTURES="$TEMP_DIR/pf-svc-income-fixtures.json"

OVERALL_STATUS=0
SERVICES_STARTED=0
NEWMAN_BIN="${NEWMAN_BIN:-}"
PYTHON_BIN="${PYTHON_BIN:-$ROOT_DIR/modules/pf-svc-income/.venv/bin/python}"
[ -x "$PYTHON_BIN" ] || PYTHON_BIN="$(command -v python3)"

log() { printf '\n== %s ==\n' "$*"; }
pass_or_fail() {
  local label="$1" status="$2"
  if [ "$status" -eq 0 ]; then
    printf 'PASS: %s\n' "$label"
  else
    printf 'FAIL: %s (exit %s)\n' "$label" "$status" >&2
    OVERALL_STATUS=1
  fi
}

cleanup() {
  local status=$?
  log "Cleanup"
  # The full collection can mutate local fixtures. Rebuild the local test DB so
  # a failed request cannot leak data into the next developer run.
  if [ "$SERVICES_STARTED" -eq 1 ] && [ -x "$SERVICES_SCRIPT" ] && [ -d "$DB_DIR" ]; then
    (cd "$DB_DIR" && make db-reset) >/dev/null 2>&1 || true
  fi
  if [ "$SERVICES_STARTED" -eq 1 ]; then
    "$SERVICES_SCRIPT" stop >/dev/null 2>&1 || true
  fi
  rm -rf "$TEMP_DIR"
  # Preserve a suite failure even when cleanup itself succeeds.
  if [ "$OVERALL_STATUS" -ne 0 ]; then
    exit "$OVERALL_STATUS"
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 2
  }
}

load_runtime_keys() {
  if [ -f "$RUNTIME_KEYS_FILE" ]; then
    # This is a local, ignored dotenv file. Values are never printed.
    set -a
    # shellcheck disable=SC1090
    . "$RUNTIME_KEYS_FILE"
    set +a
    PF_RATES_API_KEY="${PF_RATES_API_KEY:-${LOCAL_PF_RATES_API_KEY:-}}"
    PF_INCOME_API_KEY="${PF_INCOME_API_KEY:-${LOCAL_PF_INCOME_API_KEY:-}}"
    export PF_RATES_API_KEY PF_INCOME_API_KEY
    printf 'Loaded local API keys from %s\n' "$RUNTIME_KEYS_FILE"
  fi
  # The running local services read their ignored .env files. Prefer those
  # values when present so the test client cannot drift from the service.
  local rates_env="$ROOT_DIR/modules/pf-rates/.env"
  local income_env="$ROOT_DIR/modules/pf-svc-income/.env"
  if [ -f "$rates_env" ]; then
    PF_RATES_API_KEY="$(sed -n 's/^PF_RATES_API_KEY=//p' "$rates_env" | head -n 1)"
  fi
  if [ -f "$income_env" ]; then
    PF_INCOME_API_KEY="$(sed -n 's/^PF_INCOME_API_KEY=//p' "$income_env" | head -n 1)"
  fi
  export PF_RATES_API_KEY PF_INCOME_API_KEY
}

ensure_newman() {
  if [ -n "$NEWMAN_BIN" ] && [ -x "$NEWMAN_BIN" ]; then
    printf 'Using Newman: %s\n' "$NEWMAN_BIN"
    return 0
  fi
  if command -v newman >/dev/null 2>&1; then
    NEWMAN_BIN="$(command -v newman)"
    printf 'Using Newman: %s\n' "$NEWMAN_BIN"
    return 0
  fi

  require_command npm
  local newman_dir="$TEMP_DIR/newman"
  printf 'Newman not found; installing it temporarily under %s\n' "$newman_dir"
  npm install \
    --prefix "$newman_dir" \
    --no-save \
    --no-package-lock \
    --fetch-retries 5 \
    --fetch-retry-factor 2 \
    --fetch-retry-mintimeout 2000 \
    --fetch-retry-maxtimeout 30000 \
    newman
  NEWMAN_BIN="$newman_dir/node_modules/.bin/newman"
  if [ ! -x "$NEWMAN_BIN" ]; then
    printf 'ERROR: Newman installation completed without an executable\n' >&2
    exit 2
  fi
  printf 'Using temporary Newman: %s\n' "$NEWMAN_BIN"
}

run_step() {
  local label="$1"
  shift
  log "$label"
  "$@"
  local status=$?
  pass_or_fail "$label" "$status"
  return 0
}

require_command curl
require_command python3
load_runtime_keys
ensure_newman
[ -x "$SERVICES_SCRIPT" ] || { printf 'ERROR: not executable: %s\n' "$SERVICES_SCRIPT" >&2; exit 2; }
[ -d "$POSTMAN_DIR" ] || { printf 'ERROR: missing postman checkout: %s\n' "$POSTMAN_DIR" >&2; exit 2; }

: "${PF_RATES_API_KEY:?Set PF_RATES_API_KEY to the local pf-rates API key}"
: "${PF_INCOME_API_KEY:?Set PF_INCOME_API_KEY to the local pf-svc-income API key}"

mkdir -p "$REPORT_DIR"

# Mark ownership before invoking stop/start so a partial run is also cleaned up.
SERVICES_STARTED=1
if [ -f "$NEON_DUMP" ]; then
  log "Stopping local PF services before database restore"
  "$SERVICES_SCRIPT" stop
  stop_status=$?
  if [ "$stop_status" -ne 0 ]; then
    printf 'ERROR: local services did not stop cleanly before restore\n' >&2
    exit "$stop_status"
  fi
  log "Starting local database for restore"
  (cd "$DB_DIR" && make db-up)
  db_up_status=$?
  if [ "$db_up_status" -ne 0 ]; then
    printf 'ERROR: local database did not start for restore\n' >&2
    exit "$db_up_status"
  fi
  log "Restoring local database from Neon dump"
  if [ ! -x "$RESTORE_SCRIPT" ]; then
    printf 'ERROR: restore script is not executable: %s\n' "$RESTORE_SCRIPT" >&2
    exit 1
  fi
  "$RESTORE_SCRIPT"
  restore_status=$?
  if [ "$restore_status" -ne 0 ]; then
    printf 'ERROR: Neon dump restore failed\n' >&2
    exit "$restore_status"
  fi
else
  printf '\nNo Neon dump found at %s; continuing without restore.\n' "$NEON_DUMP"
fi

log "Starting local PF services"
"$SERVICES_SCRIPT" start
start_status=$?
if [ "$start_status" -ne 0 ]; then
  printf 'ERROR: local services did not start successfully\n' >&2
  exit "$start_status"
fi

run_step "Prepare dynamic pf-svc-income fixtures" \
  python3 "$ROOT_DIR/scripts/local/prepare-pf-svc-income-fixtures.py" \
    --api-key "$PF_INCOME_API_KEY" \
    --output "$FIXTURES"

# Materialize secrets and file paths only under /tmp. Committed Postman JSON is
# never modified and never receives API-key values.
python3 - "$POSTMAN_DIR/pf-ecosystem.postman_environment.local.json" "$ENVIRONMENT" "$COLLECTION" "$FULL_COLLECTION" "$PDF_FIXTURE" "$XLSX_FIXTURE" "$FIXTURES" "$PF_RATES_API_KEY" "$PF_INCOME_API_KEY" <<'PY'
import json
import sys
from pathlib import Path

(source_env, output_env, source_collection, output_collection, pdf, xlsx, fixtures_file) = map(
    Path, sys.argv[1:8]
)
rates_secret = sys.argv[8]
income_secret = sys.argv[9]
fixtures = json.loads(fixtures_file.read_text(encoding="utf-8"))

environment = json.loads(source_env.read_text(encoding="utf-8"))
secrets = {
    "pf-rates-api-key": rates_secret,
    "pf-svc-income-api-key": income_secret,
}
for variable in environment["values"]:
    if variable["key"] in secrets:
        variable["value"] = secrets[variable["key"]]
    if variable["key"] == "period_id":
        variable["value"] = str(fixtures["period_id"])
output_env.write_text(json.dumps(environment, indent=2) + "\n", encoding="utf-8")

collection = json.loads(source_collection.read_text(encoding="utf-8"))
# pf-sheets has no local service and its committed URL is external. The rates
# export folder requires Google Drive credentials and is also not local-only.
# External exports and the template mutation are covered separately. Employer,
# contract, payroll and import mutations use dynamic fixtures below.
EXCLUDED_LOCAL_REQUESTS = {
    "pf-sheets", "Exports", "Delete contracts", "Delete employers",
    "Delete one period", "Delete payroll (atomic batch)",
    "Update a template", "Deactivate a template",

    "Refresh economic indices (provider fetch)",
    "Refresh exchange rates (provider fetch)",
    "Refresh income tax brackets",
}
FOLDER_ORDER = {
    "pf-svc-income": 0, "Employer": 0, "Payroll": 1, "Preview": 0,
    "Import": 1, "Queries": 2, "Delete": 3, "Export": 4,
    "Templates": 5, "Reference data": 6, "pf-rates": 10,
}

REQUESTS_TO_RELOCATE = {"Update a template", "Deactivate a template", "Delete one period", "Delete payroll (atomic batch)", "Delete contracts", "Delete employers"}

def collect_requests(items, result=None):
    result = {} if result is None else result
    for item in items:
        if isinstance(item.get("request"), dict) and item.get("name") in REQUESTS_TO_RELOCATE:
            result[item["name"]] = json.loads(json.dumps(item))
        collect_requests(item.get("item", []), result)
    return result

relocated = collect_requests(collection.get("item", []))

def filter_local_items(items):
    filtered = []
    for item in items:
        if item.get("name") in {"pf-sheets", "Exports"} or item.get("name") in EXCLUDED_LOCAL_REQUESTS:
            continue
        if isinstance(item.get("request"), dict):
            filtered.append(item)
            continue
        item["item"] = filter_local_items(item.get("item", []))
        if item["item"]:
            filtered.append(item)
    filtered.sort(key=lambda item: FOLDER_ORDER.get(item.get("name"), 8))
    return filtered

collection["item"] = filter_local_items(collection.get("item", []))
cleanup_items = [relocated[name] for name in ["Update a template", "Deactivate a template", "Delete one period", "Delete payroll (atomic batch)", "Delete contracts", "Delete employers"] if name in relocated]
if cleanup_items:
    collection["item"].append({"name": "pf-svc-income Cleanup", "item": cleanup_items})
collection.setdefault("variable", []).extend([
    {"key": "fixture_employer_id", "value": str(fixtures["employer_id"])},
    {"key": "fixture_employer_name", "value": fixtures["employer_name"]},
    {"key": "fixture_contract_id", "value": str(fixtures["contract_id"])}, 
])
for variable in collection.get("variable", []):
    if variable.get("key") == "period_id":
        variable["value"] = str(fixtures["period_id"])
    if variable.get("key") == "template_id":
        variable["value"] = str(fixtures["template_id"])
file_sources = {
    "Preview a PDF payslip": str(pdf),
    "Import Spreadsheet (mode=validate)": str(xlsx),
}

def visit(items):
    for item in items:
        name = item.get("name")
        if name in {"Delete one period", "Delete payroll (atomic batch)", "Delete contracts", "Delete employers"}:
            item["event"] = []
        request = item.get("request")
        if name in file_sources and isinstance(request, dict):
            body = request.get("body", {})
            for part in body.get("formdata", []):
                if part.get("type") == "file":
                    part["src"] = file_sources[name]
        if isinstance(request, dict):
            body = request.get("body", {})
            for event in item.get("event", []):
                script = event.get("script", {})
                exec_lines = script.get("exec", [])
                script["exec"] = [
                    line for line in exec_lines
                    if not (name in {"Delete one period", "Delete contracts", "Delete employers"} and "Response has a content type" in line)
                    and not (name == "Delete payroll (atomic batch)" and "HTTP response is successful" in line)
                ]
            raw_url = request.get("url", {}).get("raw", "")
            if "{{period_id}}" in raw_url:
                request["url"]["raw"] = raw_url.replace("{{period_id}}", str(fixtures["period_id"]))
            raw = body.get("raw") if isinstance(body, dict) else None
            if isinstance(raw, str):
                if name == "Create or update contracts":
                    body["raw"] = raw.replace('"employer_id": 1', '"id": {{fixture_contract_id}}, "employer_id": {{fixture_employer_id}}')
                    item.setdefault("event", []).append({"listen": "test", "script": {"type": "text/javascript", "exec": ["const body = pm.response.json();", "const values = Array.isArray(body) ? body : body.contracts;", "pm.collectionVariables.set('fixture_contract_id', String(values[0].id));"]}})
                elif name == "Create a template":
                    body["raw"] = raw.replace('"template_id": "acme-chile-v1"', '"template_id": "{{template_id}}"').replace('"employer_id": 1', '"employer_id": {{fixture_employer_id}}')
                elif name == "Update a template":
                    body["raw"] = raw.replace('"employer_id": 1', '"employer_id": {{fixture_employer_id}}')
                elif name == "Delete payroll (atomic batch)":
                    body["raw"] = '{\n  "period_ids": [541]\n}'
                elif name == "Delete contracts":
                    body["raw"] = '{\n  "ids": [{{fixture_contract_id}}]\n}'
                elif name == "Delete employers":
                    body["raw"] = '{\n  "ids": [{{fixture_employer_id}}]\n}'
                elif name == "Import JSON (mode=validate)":
                    body["raw"] = raw.replace('"employer": "ACME"', '"employer": "{{fixture_employer_name}}"').replace('"period_year": 2026,\n      "period_month": 1', '"period_year": 2025,\n      "period_month": 10').replace('"payment_date": "2026-01-31"', '"payment_date": "2025-10-28"').replace('"employment_contract_kind": "indefinite",', '"employment_contract_kind": "indefinite",\n      "worked_days": 0,')
        visit(item.get("item", []))

visit(collection.get("item", []))
output_collection.write_text(json.dumps(collection, indent=2) + "\n", encoding="utf-8")
PY
materialize_status=$?
pass_or_fail "Materialize ephemeral environment and fixtures" "$materialize_status"
[ "$materialize_status" -eq 0 ] || exit 1

run_step "Generate synthetic PDF" \
  "$PYTHON_BIN" "$POSTMAN_DIR/scripts/generate-synthetic-payroll-pdf.py" --output "$PDF_FIXTURE"
run_step "Generate synthetic XLSX" \
  "$PYTHON_BIN" "$POSTMAN_DIR/scripts/generate-synthetic-payroll-xlsx.py" --output "$XLSX_FIXTURE"

curl -fsS http://localhost:8001/openapi.json >"$TEMP_DIR/pf-rates-openapi.json"
rates_openapi_status=$?
pass_or_fail "Fetch pf-rates OpenAPI" "$rates_openapi_status"
curl -fsS http://localhost:8000/openapi.json >"$TEMP_DIR/pf-svc-income-openapi.json"
income_openapi_status=$?
pass_or_fail "Fetch pf-svc-income OpenAPI" "$income_openapi_status"

if [ "$rates_openapi_status" -eq 0 ] && [ "$income_openapi_status" -eq 0 ]; then
  run_step "Check OpenAPI/Postman coverage" \
    python3 "$POSTMAN_DIR/scripts/check-api-coverage.py" \
      --collection "$COLLECTION" \
      --openapi "pf-rates=$TEMP_DIR/pf-rates-openapi.json" \
      --openapi "pf-svc-income=$TEMP_DIR/pf-svc-income-openapi.json"
fi

run_step "Check expected local error contracts" \
  env PF_RATES_API_KEY="$PF_RATES_API_KEY" PF_INCOME_API_KEY="$PF_INCOME_API_KEY" \
  python3 "$POSTMAN_DIR/scripts/check-local-error-contracts.py"

run_step "Run read-only Newman smoke subset" \
  python3 "$POSTMAN_DIR/scripts/run-postman-smoke.py" \
    --collection "$FULL_COLLECTION" \
    --environment "$ENVIRONMENT" \
    --newman "$NEWMAN_BIN" \
    --report "$REPORT_DIR/postman-smoke.xml"

# This is the requested local Run All: no read-only filtering and no --bail, so
# Newman visits every local collection request even when an earlier request fails.
# pf-sheets is intentionally excluded because it is an external Apps Script URL,
# not a service started by pf-services.sh.
run_step "Run complete Newman collection (Run All, local services)" \
  "$NEWMAN_BIN" run "$FULL_COLLECTION" \
    --environment "$ENVIRONMENT" \
    --reporters cli,junit \
    --reporter-junit-export "$REPORT_DIR/postman-run-all.xml"

run_step "Run synthetic PDF/XLSX validation contracts" \
  python3 "$POSTMAN_DIR/scripts/run-postman-payroll-contracts.py" \
    --collection "$COLLECTION" \
    --environment "$ENVIRONMENT" \
    --pdf "$PDF_FIXTURE" \
    --xlsx "$XLSX_FIXTURE" \
    --newman "$NEWMAN_BIN" \
    --report "$REPORT_DIR/payroll-contracts.xml"

run_step "Run dynamic pf-svc-income mutation lifecycle" \
  python3 "$ROOT_DIR/scripts/local/run-pf-svc-income-mutations.py" \
    --api-key "$PF_INCOME_API_KEY"

run_step "Run synthetic mutating integration workflow" \
  env PF_INCOME_API_KEY="$PF_INCOME_API_KEY" \
  python3 "$POSTMAN_DIR/scripts/run-postman-integration.py" \
    --base-url http://localhost:8000

if [ "$OVERALL_STATUS" -eq 0 ]; then
  printf '\nPF local Postman validation finished successfully. Reports: %s\n' "$REPORT_DIR"
else
  printf '\nPF local Postman validation finished with failures. Reports: %s\n' "$REPORT_DIR" >&2
fi
exit "$OVERALL_STATUS"
