#!/usr/bin/env bash
set -euo pipefail
umask 077

PROJECT_ID="coreassistant-474022"
POOL_ID="github-actions"
PROVIDER_ID="github-actions-oidc"
ORG="mrturo-pf"
PROJECT_NUMBER="646185261155"
ID="imp-005"
N="06"
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
mkdir -m 700 "$DIR"

STEP=project
gcloud projects describe "$PROJECT_ID" \
  --format='json(projectId,projectNumber,lifecycleState,name)' >"$DIR/project.json"

STEP=session
gcloud auth list --filter=status:ACTIVE --format='value(account)' >"$DIR/session.txt"
grep -q . "$DIR/session.txt"

STEP=provider
gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --project="$PROJECT_ID" --location=global --workload-identity-pool="$POOL_ID" \
  --format=json >"$DIR/provider.json"
condition="$(gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --project="$PROJECT_ID" --location=global --workload-identity-pool="$POOL_ID" \
  --format='value(attributeCondition)')"
printf '%s\n' "$condition" >"$DIR/provider-condition.txt"
expected="assertion.repository_owner == 'mrturo-pf' && (assertion.repository == 'mrturo-pf/pf-rates' || assertion.repository == 'mrturo-pf/pf-payroll') && assertion.ref == 'refs/heads/main' && assertion.environment == 'GCP'"
[[ "$condition" == "$expected" ]]

STEP=accounts
for service in pf-rates pf-payroll; do
  account="${service}-deployer"
  if gcloud iam service-accounts describe "${account}@${PROJECT_ID}.iam.gserviceaccount.com" \
      --project="$PROJECT_ID" --format=json >"$DIR/${account}-before.json" 2>"$DIR/${account}-before.error"; then
    printf '%s\n' "${account}=exists" >>"$DIR/accounts.txt"
  else
    printf '%s\n' "${account}=missing" >>"$DIR/accounts.txt"
  fi
done

printf '%s\n' 'Planned mutations:'
printf '%s\n' '- create missing pf-rates-deployer and/or pf-payroll-deployer service accounts'
printf '%s\n' '- grant only roles/iam.workloadIdentityUser on each matching service account'
printf '%s' 'Continue? [y/N] '
read -r answer
[[ "$answer" == y || "$answer" == Y ]]

for service in pf-rates pf-payroll; do
  account="${service}-deployer"
  email="${account}@${PROJECT_ID}.iam.gserviceaccount.com"
  if ! gcloud iam service-accounts describe "$email" --project="$PROJECT_ID" --format='value(email)' >/dev/null 2>&1; then
    STEP="create_${account}"
    gcloud iam service-accounts create "$account" --project="$PROJECT_ID" \
      --display-name="${service} GitHub Actions deployer" \
      --description="WIF deployer for ${ORG}/${service}; no runtime use" --quiet
  fi
  STEP="bind_${account}"
  member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${ORG}/${service}"
  gcloud iam service-accounts add-iam-policy-binding "$email" \
    --project="$PROJECT_ID" --role=roles/iam.workloadIdentityUser \
    --member="$member" --quiet
  printf '%s\t%s\n' "$email" "$member" >>"$DIR/workload-identity-bindings.tsv"
done

STEP=verify
for service in pf-rates pf-payroll; do
  account="${service}-deployer@${PROJECT_ID}.iam.gserviceaccount.com"
  gcloud iam service-accounts get-iam-policy "$account" --project="$PROJECT_ID" \
    --format=json >"$DIR/${service}-deployer-after.json"
done

STEP=summary
cat >"$DIR/summary.md" <<EOF
# IMP-005 WIF deployer identity summary

- project: $PROJECT_ID
- pool: $POOL_ID
- provider: $PROVIDER_ID
- mutations: service-specific deployer accounts and workloadIdentityUser bindings only
- deploy permissions: none
- runtime permissions: none
- workflow changes: none
- key revocation: none
- secrets_recorded: false
- private_keys_recorded: false
- raw_business_data_recorded: false
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
