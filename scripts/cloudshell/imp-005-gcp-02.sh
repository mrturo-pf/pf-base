#!/usr/bin/env bash
set -euo pipefail
umask 077

PROJECT_ID="coreassistant-474022"
REGION="us-central1"
ID="imp-005"
N="02"
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

STEP=artifact_registry
: >"$DIR/artifact-registry-iam.jsonl"
for repository in pf-rates pf-payroll; do
  if gcloud artifacts repositories describe "$repository" \
      --location="$REGION" --project="$PROJECT_ID" --format='value(name)' \
      >"$DIR/${repository}-repository.txt" 2>"$DIR/${repository}-repository.error"; then
    gcloud artifacts repositories get-iam-policy "$repository" \
      --location="$REGION" --project="$PROJECT_ID" --format=json \
      | jq --arg repository "$repository" \
        '{resource: $repository, bindings: .bindings}' \
      >>"$DIR/artifact-registry-iam.jsonl"
  else
    printf '{"resource":"%s","status":"missing-or-inaccessible"}\n' "$repository" \
      >>"$DIR/artifact-registry-iam.jsonl"
  fi
done

STEP=secret_manager
: >"$DIR/secret-iam.jsonl"
for secret in PF_RATES_API_KEY PF_PAYROLL_API_KEY PF_DATABASE_URL PF_RATES_DATABASE_URL PF_PAYROLL_DATABASE_URL; do
  if gcloud secrets describe "$secret" --project="$PROJECT_ID" \
      --format='value(name)' >"$DIR/${secret}-metadata.txt" 2>"$DIR/${secret}-metadata.error"; then
    gcloud secrets get-iam-policy "$secret" --project="$PROJECT_ID" --format=json \
      | jq --arg secret "$secret" \
        '{resource: $secret, bindings: .bindings}' \
      >>"$DIR/secret-iam.jsonl"
  else
    printf '{"resource":"%s","status":"missing-or-inaccessible"}\n' "$secret" \
      >>"$DIR/secret-iam.jsonl"
  fi
done

STEP=cloud_run
: >"$DIR/cloud-run-identities.tsv"
for service in pf-rates pf-payroll; do
  gcloud run services describe "$service" --project="$PROJECT_ID" \
    --region="$REGION" \
    --format='value(metadata.name,spec.template.spec.serviceAccountName,status.url)' \
    >>"$DIR/cloud-run-identities.tsv" 2>"$DIR/${service}-cloud-run.error" || true
done

STEP=service_accounts
: >"$DIR/service-account-iam.jsonl"
for account in \
  "github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
  "pf-rates@${PROJECT_ID}.iam.gserviceaccount.com" \
  "pf-payroll@${PROJECT_ID}.iam.gserviceaccount.com"; do
  gcloud iam service-accounts get-iam-policy "$account" \
    --project="$PROJECT_ID" --format=json \
    | jq --arg account "$account" \
      '{resource: $account, bindings: (.bindings // [])}' \
    >>"$DIR/service-account-iam.jsonl" || \
    printf '{"resource":"%s","status":"missing-or-inaccessible"}\n' "$account" \
      >>"$DIR/service-account-iam.jsonl"
done

STEP=summary
cat >"$DIR/summary.md" <<EOF
# IMP-005 resource-level IAM inventory summary

- project: $PROJECT_ID
- region: $REGION
- mutations: none
- secret_values_recorded: false
- private_keys_recorded: false
- raw_business_data_recorded: false
- resources: Artifact Registry, Secret Manager, Cloud Run, service-account IAM
- errors: inspect *.error files; inaccessible resources are recorded as metadata only
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
