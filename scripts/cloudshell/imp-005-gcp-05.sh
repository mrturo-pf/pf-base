#!/usr/bin/env bash
set -euo pipefail
umask 077

PROJECT_ID="coreassistant-474022"
POOL_ID="github-actions"
PROVIDER_ID="github-actions-oidc"
ORG="mrturo-pf"
ID="imp-005"
N="05"
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
BASE="$PWD"
RUN="${ID}-gcp-${N}-$(date -u +%Y%m%dT%H%M%SZ)"
DIR="$BASE/$RUN"
ARCHIVE="$BASE/$RUN.tar.gz"
STEP=init

CONDITION="assertion.repository_owner == '${ORG}' && (assertion.repository == '${ORG}/pf-rates' || assertion.repository == '${ORG}/pf-payroll') && assertion.ref == 'refs/heads/main' && assertion.environment == 'GCP'"

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
mkdir -m 700 "$DIR"

STEP=project
gcloud projects describe "$PROJECT_ID" \
  --format='json(projectId,projectNumber,lifecycleState,name)' >"$DIR/project.json"

STEP=session
gcloud auth list --filter=status:ACTIVE --format='value(account)' >"$DIR/session.txt"
grep -q . "$DIR/session.txt"

STEP=before
gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --project="$PROJECT_ID" --location=global --workload-identity-pool="$POOL_ID" \
  --format=json >"$DIR/provider-before.json"

printf '%s\n' 'Planned provider condition:'
printf '%s\n' "$CONDITION"
printf '%s' 'Update this existing provider? [y/N] '
read -r answer
[[ "$answer" == y || "$answer" == Y ]]

STEP=update
gcloud iam workload-identity-pools providers update-oidc "$PROVIDER_ID" \
  --project="$PROJECT_ID" --location=global --workload-identity-pool="$POOL_ID" \
  --issuer-uri='https://token.actions.githubusercontent.com' \
  --attribute-mapping='google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref,attribute.repository_owner=assertion.repository_owner,attribute.environment=assertion.environment' \
  --attribute-condition="$CONDITION" \
  --quiet

STEP=verify
gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --project="$PROJECT_ID" --location=global --workload-identity-pool="$POOL_ID" \
  --format=json >"$DIR/provider-after.json"
actual_condition="$(gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --project="$PROJECT_ID" --location=global --workload-identity-pool="$POOL_ID" \
  --format='value(attributeCondition)')"
printf '%s\n' "$actual_condition" >"$DIR/provider-condition.txt"
[[ "$actual_condition" == "$CONDITION" ]]

STEP=summary
cat >"$DIR/summary.md" <<EOF
# IMP-005 WIF provider condition hardening summary

- project: $PROJECT_ID
- pool: $POOL_ID
- provider: $PROVIDER_ID
- mutations: provider attribute condition updated only
- service-account grants: none
- workflow changes: none
- key revocation: none
- secrets_recorded: false
- private_keys_recorded: false
- raw_business_data_recorded: false
- condition: repository owner/allowlist + main branch + GCP environment
- cleanup: remove the local archive after review through an approved channel
EOF

STEP=archive
tar -czf "$ARCHIVE" -C "$BASE" "$RUN"
tar -tzf "$ARCHIVE" >/dev/null
size="$(stat -c %s "$ARCHIVE" 2>/dev/null || stat -f %z "$ARCHIVE")"
[[ "$size" -gt 0 ]]
rm -rf -- "$DIR"

printf 'success=true archive_size=%s\n' "$size"
printf 'Verify the local archive before cleanup; then run in Cloud Shell:\nrm -f -- %q %q\n' "$ARCHIVE" "$SCRIPT_PATH"
