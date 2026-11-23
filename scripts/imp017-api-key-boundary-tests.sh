#!/usr/bin/env bash
# Run IMP-017 API-key boundary tests from the local machine.
#
# The script creates short-lived test keys, never prints their values, validates
# enabled/revoked/wrong-API behavior, and deletes every test key on exit.
# It must be run from an approved GCP/VPC Service Controls path.

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-coreassistant-474022}"
GATEWAY_HOST="${GATEWAY_HOST:-pf-backend-gateway-poc-88uq0qjn.uc.gateway.dev}"
MANAGED_SERVICE="${MANAGED_SERVICE:-pf-backend-gateway-22kzlirwl1h1g.apigateway.coreassistant-474022.cloud.goog}"
BUSINESS_PATH="${BUSINESS_PATH:-/income/payroll/contracts}"
WORK_DIR="$(mktemp -d)"
CREATED_KEYS=()

cleanup() {
  local key_id
  set +e
  if ((${#CREATED_KEYS[@]})); then
    for key_id in "${CREATED_KEYS[@]}"; do
      gcloud services api-keys delete "$key_id" \
        --project="$PROJECT_ID" --quiet >/dev/null 2>&1
    done
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  }
}

require_command gcloud
require_command curl
require_command python3

if command -v unset-proxies >/dev/null 2>&1; then
  unset-proxies >/dev/null
fi

create_key() {
  local display_name="$1"
  local target_service="$2"
  local output_file="$WORK_DIR/create-${#CREATED_KEYS[@]}.out"
  local error_file="$WORK_DIR/create-${#CREATED_KEYS[@]}.err"
  local key_id
  local key_value

  if ! gcloud services api-keys create \
    --project="$PROJECT_ID" \
    --display-name="$display_name" \
    --api-target="service=$target_service" \
    --format=json >"$output_file" 2>"$error_file"; then
    printf 'Could not create test key "%s".\n' "$display_name" >&2
    sed -n '1,8p' "$error_file" >&2
    printf 'If this reports VPC_SERVICE_CONTROLS, run the script from an approved GCP path.\n' >&2
    exit 1
  fi

  read -r key_id key_value < <(
    python3 - "$output_file" "$error_file" <<'PY'
import json
import re
import sys
from pathlib import Path

for filename in sys.argv[1:]:
    text = Path(filename).read_text(encoding="utf-8", errors="replace")
    try:
        document = json.loads(text)
    except json.JSONDecodeError:
        document = {}
    if isinstance(document, dict):
        key_id = document.get("uid") or document.get("name", "").rsplit("/", 1)[-1]
        key_value = document.get("keyString", "")
        if key_id and key_value:
            print(key_id, key_value)
            raise SystemExit
    match_id = re.search(r'"uid"\s*:\s*"([^"]+)"', text)
    match_key = re.search(r'"keyString"\s*:\s*"([^"]+)"', text)
    if match_id and match_key:
        print(match_id.group(1), match_key.group(1))
        raise SystemExit
raise SystemExit("The API did not return a test key value.")
PY
  )

  if [[ -z "$key_id" || -z "$key_value" ]]; then
    printf 'The test key was created but its value was not returned. Delete it manually using the resource list.\n' >&2
    exit 1
  fi

  CREATED_KEYS+=("$key_id")
  printf '%s\n%s\n' "$key_id" "$key_value"
}

assert_status() {
  local label="$1"
  local expected="$2"
  shift 2
  local actual
  actual=$(curl --noproxy '*' --silent --show-error --output /dev/null \
    --write-out '%{http_code}' --max-time 45 "$@")
  printf '%-38s HTTP %s\n' "$label" "$actual"
  case ",$expected," in
    *",$actual,"*) ;;
    *)
      printf 'Unexpected status for %s. Expected one of: %s\n' "$label" "$expected" >&2
      exit 1
      ;;
  esac
}

printf 'Testing gateway: https://%s%s\n' "$GATEWAY_HOST" "$BUSINESS_PATH"
printf 'Managed service: %s\n\n' "$MANAGED_SERVICE"

read -r revoked_id revoked_key < <(
  create_key "IMP-017 revoked-key test" "$MANAGED_SERVICE"
)
assert_status "enabled test key" "200" \
  -H "X-API-Key: $revoked_key" \
  "https://$GATEWAY_HOST$BUSINESS_PATH"

# API Keys v2 has no disable flag in gcloud; deletion is the supported
# revocation/deactivation operation. The deleted key must then be rejected.
gcloud services api-keys delete "$revoked_id" \
  --project="$PROJECT_ID" --quiet >/dev/null
assert_status "revoked test key" "400,401,403" \
  -H "X-API-Key: $revoked_key" \
  "https://$GATEWAY_HOST$BUSINESS_PATH"

read -r wrong_api_id wrong_api_key < <(
  create_key "IMP-017 wrong-api test" "storage.googleapis.com"
)
assert_status "key restricted to another API" "400,401,403" \
  -H "X-API-Key: $wrong_api_key" \
  "https://$GATEWAY_HOST$BUSINESS_PATH"

printf '\nIMP-017 API-key boundary tests passed. Test keys will be deleted automatically.\n'
