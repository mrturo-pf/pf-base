#!/usr/bin/env bash
set -euo pipefail
umask 077

PROJECT_ID="coreassistant-474022"
REGION="us-central1"
ID="imp-005"
N="01"
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
BASE="$PWD"
RUN="${ID}-gcp-${N}-$(date -u +%Y%m%dT%H%M%SZ)"
DIR="$BASE/$RUN"
ARCHIVE="$BASE/$RUN.tar.gz"
STEP=init

fail() {
  local status=$?
  if [[ -d "$DIR" ]]; then
    printf '%s\n' "status=failed" "failed_step=$STEP" "secrets_recorded=false" \
      >"$DIR/failure.txt" 2>/dev/null || true
  fi
  printf 'status=failed step=%s exit_code=%s\n' "$STEP" "$status" >&2
  exit "$status"
}
trap fail ERR

command -v gcloud >/dev/null || { printf 'missing_command=gcloud\n' >&2; exit 1; }
command -v jq >/dev/null || { printf 'missing_command=jq\n' >&2; exit 1; }
mkdir -m 700 "$DIR"

STEP=project
gcloud projects describe "$PROJECT_ID" \
  --format='json(projectId,projectNumber,lifecycleState,name)' >"$DIR/project.json"

STEP=session
gcloud auth list --filter=status:ACTIVE --format='value(account)' >"$DIR/session.txt"
grep -q . "$DIR/session.txt"

STEP=org_policy
gcloud org-policies list --project="$PROJECT_ID" \
  --format=json >"$DIR/org-policies.json"

STEP=iam_policy
gcloud projects get-iam-policy "$PROJECT_ID" --format=json \
  | jq '{bindings: [.bindings[] | select(.role | test("workloadIdentity|serviceAccountUser|serviceAccountTokenCreator|run|artifactregistry|secretmanager|cloudsql"; "i"))]}' \
  >"$DIR/relevant-project-iam.json"

STEP=wif_pools
gcloud iam workload-identity-pools list \
  --project="$PROJECT_ID" --location=global --format=json \
  >"$DIR/wif-pools.json"

STEP=wif_providers
: >"$DIR/wif-providers.jsonl"
while IFS= read -r pool; do
  [[ -n "$pool" ]] || continue
  gcloud iam workload-identity-pools providers list \
    --project="$PROJECT_ID" --location=global \
    --workload-identity-pool="$pool" --format=json \
    | jq --arg pool "$pool" '{pool: $pool, providers: .}' \
    >>"$DIR/wif-providers.jsonl"
done < <(jq -r '.[].name | split("/")[-1]' "$DIR/wif-pools.json")

STEP=summary
cat >"$DIR/summary.md" <<EOF
# IMP-005 GCP inventory summary

- project: $PROJECT_ID
- region: $REGION
- mutations: none
- secrets_recorded: false
- raw_business_data_recorded: false
- queries: project, session, org policies, relevant project IAM, WIF pools/providers
- cleanup: remove the local archive after it has been reviewed and attached only through an approved channel
EOF

STEP=archive
tar -czf "$ARCHIVE" -C "$BASE" "$RUN"
tar -tzf "$ARCHIVE" >/dev/null
size="$(stat -c %s "$ARCHIVE" 2>/dev/null || stat -f %z "$ARCHIVE")"
[[ "$size" -gt 0 ]]
rm -rf -- "$DIR"

printf 'success=true archive_size=%s\n' "$size"
printf 'Verify the local archive before cleanup; then run in Cloud Shell:\nrm -f -- %q %q\n' "$ARCHIVE" "$SCRIPT_PATH"
