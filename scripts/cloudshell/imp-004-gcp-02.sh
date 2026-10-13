#!/usr/bin/env bash
set -euo pipefail
umask 077

PROJECT_ID="coreassistant-474022"
REGION="us-central1"
ID="imp-004"
N="02"
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
BASE="$PWD"
RUN="${ID}-gcp-${N}-$(date -u +%Y%m%dT%H%M%SZ)"
DIR="$BASE/$RUN"
ARCHIVE="$BASE/$RUN.tar.gz"
STEP=init
API_KEY=""

fail() {
  status=$?
  unset API_KEY
  if [[ -d "$DIR" ]]; then
    printf 'status=failed step=%s exit_code=%s\n' "$STEP" "$status" >"$DIR/failure.txt"
  fi
  printf 'status=failed step=%s exit_code=%s\n' "$STEP" "$status" >&2
  exit "$status"
}
trap fail ERR
trap 'unset API_KEY' EXIT

for command_name in gcloud jq curl tar; do
  command -v "$command_name" >/dev/null || {
    printf '%s is required\n' "$command_name" >&2
    exit 1
  }
done
[[ "$PROJECT_ID" == "coreassistant-474022" ]] || {
  printf 'unexpected PROJECT_ID\n' >&2
  exit 2
}
mkdir -m 700 "$DIR"

STEP=project
gcloud projects describe "$PROJECT_ID" --format=json >"$DIR/project.json"
STEP=session
gcloud auth list --filter=status:ACTIVE --format='value(account)' >"$DIR/session.txt"
grep -q . "$DIR/session.txt"

STEP=service
BASE_URL="$(gcloud run services describe pf-rates --project="$PROJECT_ID" --region="$REGION" --format='value(status.url)')"
[[ "$BASE_URL" == https://* ]]
REVISION="$(gcloud run services describe pf-rates --project="$PROJECT_ID" --region="$REGION" --format='value(status.latestReadyRevisionName)')"
printf 'service=pf-rates\nrevision=%s\nbase_url=%s\n' "$REVISION" "$BASE_URL" >"$DIR/service.txt"

STEP=health
health_status="$(curl --silent --show-error --max-time 30 --output /dev/null --write-out '%{http_code}' "$BASE_URL/health")"
printf 'health_status=%s\n' "$health_status" >"$DIR/health.txt"
[[ "$health_status" == 200 ]]

STEP=secret
API_KEY="$(gcloud secrets versions access latest --secret=PF_RATES_API_KEY --project="$PROJECT_ID")"
[[ -n "$API_KEY" ]]

STEP=authenticated-read
auth_status="$(curl --silent --show-error --max-time 30 --output /dev/null --write-out '%{http_code}' \
  -H "X-API-Key: $API_KEY" "$BASE_URL/monetary-units")"
printf 'authenticated_read_endpoint=/monetary-units\nauthenticated_read_status=%s\n' "$auth_status" >"$DIR/authenticated-read.txt"
[[ "$auth_status" == 200 ]]
unset API_KEY

STEP=summary
cat >"$DIR/summary.md" <<EOF
# Summary

- project: $PROJECT_ID
- region: $REGION
- service: pf-rates
- revision: $REVISION
- health endpoint: HTTP $health_status
- authenticated read endpoint: HTTP $auth_status
- secret values: read only in memory and unset after request
- response bodies: not persisted
- mutations: none
- cleanup: remove the local archive and this script only after the archive is verified
EOF

STEP=archive
tar -czf "$ARCHIVE" -C "$BASE" "$RUN"
tar -tzf "$ARCHIVE" >/dev/null
size="$(stat -c %s "$ARCHIVE" 2>/dev/null || stat -f %z "$ARCHIVE")"
[[ "$size" -gt 0 ]]
rm -rf -- "$DIR"

rel="${ARCHIVE#$HOME/}"
[[ "$rel" != "$ARCHIVE" ]] || rel="$ARCHIVE"
printf 'success=true archive_size=%s\n' "$size"
printf 'gcloud cloud-shell scp cloudshell:~/%s localhost:./ --project=%s\n' "$rel" "$PROJECT_ID"
printf 'Verify the local archive before cleanup; then run in Cloud Shell:\nrm -f -- %q %q\n' "$ARCHIVE" "$SCRIPT_PATH"
