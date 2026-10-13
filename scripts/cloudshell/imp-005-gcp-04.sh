#!/usr/bin/env bash
set -euo pipefail
umask 077

PROJECT_ID="coreassistant-474022"
POOL_ID="github-actions"
PROVIDER_ID="github-actions-oidc"
ORG="mrturo-pf"
ID="imp-005"
N="04"
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

STEP=list_pool
POOL_EXISTS=false
if gcloud iam workload-identity-pools describe "$POOL_ID" \
    --project="$PROJECT_ID" --location=global --format=json \
    >"$DIR/pool-before.json" 2>"$DIR/pool-before.error"; then
  POOL_EXISTS=true
fi

STEP=list_provider
PROVIDER_EXISTS=false
if [[ "$POOL_EXISTS" == true ]] && gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
    --project="$PROJECT_ID" --location=global --workload-identity-pool="$POOL_ID" \
    --format=json >"$DIR/provider-before.json" 2>"$DIR/provider-before.error"; then
  PROVIDER_EXISTS=true
fi

printf '%s\n' "project=$PROJECT_ID" "pool=$POOL_ID" "provider=$PROVIDER_ID" \
  "organization=$ORG" "pool_exists=$POOL_EXISTS" "provider_exists=$PROVIDER_EXISTS"

if [[ "$POOL_EXISTS" == true || "$PROVIDER_EXISTS" == true ]]; then
  printf '%s\n' 'Existing WIF resources detected; no mutation will be performed.'
  MUTATIONS=none
else
  printf '%s\n' 'Planned mutations:'
  printf '%s\n' "- create global pool: $POOL_ID"
  printf '%s\n' "- create OIDC provider: $PROVIDER_ID"
  printf '%s\n' "- restrict repositories to ${ORG}/pf-rates and ${ORG}/pf-payroll"
  printf '%s' 'Continue with these mutations? [y/N] '
  read -r answer
  [[ "$answer" == y || "$answer" == Y ]]

  STEP=create_pool
  gcloud iam workload-identity-pools create "$POOL_ID" \
    --project="$PROJECT_ID" --location=global \
    --display-name='PF GitHub Actions' \
    --description='OIDC federation for approved PF GitHub Actions repositories' \
    --quiet

  STEP=create_provider
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
    --project="$PROJECT_ID" --location=global --workload-identity-pool="$POOL_ID" \
    --display-name='PF GitHub Actions OIDC' \
    --description='GitHub OIDC provider restricted to approved PF repositories' \
    --issuer-uri='https://token.actions.githubusercontent.com' \
    --attribute-mapping='google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref,attribute.repository_owner=assertion.repository_owner,attribute.environment=assertion.environment' \
    --attribute-condition="assertion.repository_owner == '${ORG}' && (assertion.repository == '${ORG}/pf-rates' || assertion.repository == '${ORG}/pf-payroll')" \
    --quiet
  MUTATIONS='pool and provider created'
fi

STEP=verify
gcloud iam workload-identity-pools describe "$POOL_ID" \
  --project="$PROJECT_ID" --location=global --format=json >"$DIR/pool-after.json"
gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --project="$PROJECT_ID" --location=global --workload-identity-pool="$POOL_ID" \
  --format=json >"$DIR/provider-after.json"

STEP=summary
cat >"$DIR/summary.md" <<EOF
# IMP-005 WIF resource preparation summary

- project: $PROJECT_ID
- pool: $POOL_ID
- provider: $PROVIDER_ID
- github_owner: $ORG
- mutations: $MUTATIONS
- service-account grants: none
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
