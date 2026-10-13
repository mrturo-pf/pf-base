#!/usr/bin/env bash
set -euo pipefail
umask 077

PROJECT_ID="coreassistant-474022"
REGION="us-central1"
POOL_ID="github-actions"
PROVIDER_ID="github-actions-oidc"
ID="imp-005"
N="07"
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

STEP=provider
gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --project="$PROJECT_ID" --location=global --workload-identity-pool="$POOL_ID" \
  --format=json >"$DIR/provider.json"
condition="$(gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --project="$PROJECT_ID" --location=global --workload-identity-pool="$POOL_ID" \
  --format='value(attributeCondition)')"
expected="assertion.repository_owner == 'mrturo-pf' && (assertion.repository == 'mrturo-pf/pf-rates' || assertion.repository == 'mrturo-pf/pf-payroll') && assertion.ref == 'refs/heads/main' && assertion.environment == 'GCP'"
[[ "$condition" == "$expected" ]]
printf '%s\n' "$condition" >"$DIR/provider-condition.txt"

STEP=accounts
for service in pf-rates pf-payroll; do
  deployer="${service}-deployer@${PROJECT_ID}.iam.gserviceaccount.com"
  runtime="${service}@${PROJECT_ID}.iam.gserviceaccount.com"
  gcloud iam service-accounts describe "$deployer" --project="$PROJECT_ID" --format=json \
    >"$DIR/${service}-deployer.json"
  gcloud iam service-accounts describe "$runtime" --project="$PROJECT_ID" --format=json \
    >"$DIR/${service}-runtime.json"
done

STEP=policies
for service in pf-rates pf-payroll; do
  gcloud artifacts repositories get-iam-policy "$service" --location="$REGION" \
    --project="$PROJECT_ID" --format=json >"$DIR/${service}-artifact-policy-before.json" || true
  gcloud iam service-accounts get-iam-policy \
    "${service}@${PROJECT_ID}.iam.gserviceaccount.com" --project="$PROJECT_ID" \
    --format=json >"$DIR/${service}-runtime-policy-before.json"
done
gcloud projects get-iam-policy "$PROJECT_ID" --format=json >"$DIR/project-policy-before.json"

printf '%s\n' 'Planned mutations per service:'
printf '%s\n' '- grant roles/run.developer to the service deployer at project scope'
printf '%s\n' '- grant roles/artifactregistry.writer on the matching Artifact Registry repository'
printf '%s\n' '- grant roles/iam.serviceAccountUser on the matching runtime service account'
printf '%s\n' 'No Secret Manager, Cloud SQL, database, runtime, run.admin, or key mutations.'
printf '%s' 'Continue? [y/N] '
read -r answer
[[ "$answer" == y || "$answer" == Y ]]

for service in pf-rates pf-payroll; do
  deployer="${service}-deployer@${PROJECT_ID}.iam.gserviceaccount.com"
  runtime="${service}@${PROJECT_ID}.iam.gserviceaccount.com"
  STEP="grant_${service}_run_developer"
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${deployer}" --role=roles/run.developer --quiet
  STEP="grant_${service}_artifact_writer"
  gcloud artifacts repositories add-iam-policy-binding "$service" \
    --location="$REGION" --project="$PROJECT_ID" \
    --member="serviceAccount:${deployer}" \
    --role=roles/artifactregistry.writer --quiet
  STEP="grant_${service}_runtime_user"
  gcloud iam service-accounts add-iam-policy-binding "$runtime" \
    --project="$PROJECT_ID" \
    --member="serviceAccount:${deployer}" \
    --role=roles/iam.serviceAccountUser --quiet
done

STEP=verify
for service in pf-rates pf-payroll; do
  gcloud artifacts repositories get-iam-policy "$service" --location="$REGION" \
    --project="$PROJECT_ID" --format=json >"$DIR/${service}-artifact-policy-after.json"
  gcloud iam service-accounts get-iam-policy \
    "${service}@${PROJECT_ID}.iam.gserviceaccount.com" --project="$PROJECT_ID" \
    --format=json >"$DIR/${service}-runtime-policy-after.json"
done
gcloud projects get-iam-policy "$PROJECT_ID" --format=json >"$DIR/project-policy-after.json"

STEP=summary
cat >"$DIR/summary.md" <<EOF
# IMP-005 WIF deployer permission summary

- project: $PROJECT_ID
- mutations: run.developer project grant, repository-scoped Artifact Registry writer, runtime-account-scoped Service Account User
- secret_manager_mutations: none
- cloudsql_mutations: none
- database_mutations: none
- runtime_identity_mutations: none
- key_revocation: none
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
