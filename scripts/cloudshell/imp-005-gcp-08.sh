#!/usr/bin/env bash
set -euo pipefail
umask 077

PROJECT_ID="coreassistant-474022"
ID="imp-005"
N="08"
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

RUNTIME_ACCOUNTS=(
  "pf-rates@${PROJECT_ID}.iam.gserviceaccount.com"
  "pf-payroll@${PROJECT_ID}.iam.gserviceaccount.com"
)
LEGACY_DEPLOYER="github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com"
LEGACY_ROLES=(
  "roles/run.admin"
  "roles/artifactregistry.writer"
  "roles/iam.serviceAccountUser"
)

STEP=project
gcloud projects describe "$PROJECT_ID" --format=json >"$DIR/project.json"
STEP=session
gcloud auth list --filter=status:ACTIVE --format='value(account)' >"$DIR/session.txt"
grep -q . "$DIR/session.txt"
STEP=before
gcloud projects get-iam-policy "$PROJECT_ID" --format=json >"$DIR/project-policy-before.json"
for account in "${RUNTIME_ACCOUNTS[@]}" "$LEGACY_DEPLOYER"; do
  safe="${account%@*}"
  gcloud iam service-accounts get-iam-policy "$account" --project="$PROJECT_ID" \
    --format=json >"$DIR/${safe}-service-policy-before.json" || true
  gcloud iam service-accounts keys list --iam-account="$account" \
    --managed-by=user --format=json >"$DIR/${safe}-keys-before.json" || true
done

printf '%s\n' 'Planned cleanup mutations:'
printf '%s\n' '- remove legacy project bindings run.admin, artifactregistry.writer, serviceAccountUser from runtime accounts'
printf '%s\n' '- remove legacy project bindings run.admin, artifactregistry.writer, serviceAccountUser from github-actions-deployer'
printf '%s\n' '- remove pf-rates service-account self-binding serviceAccountUser'
printf '%s\n' '- delete all user-managed keys for pf-rates, pf-payroll, and github-actions-deployer'
printf '%s\n' '- preserve runtime secret accessor/cloudsql grants and WIF deployer grants'
printf '%s' 'Continue with irreversible cleanup? [y/N] '
read -r answer
[[ "$answer" == y || "$answer" == Y ]]

for account in "${RUNTIME_ACCOUNTS[@]}" "$LEGACY_DEPLOYER"; do
  for role in "${LEGACY_ROLES[@]}"; do
    STEP="remove_${role##*.}_${account%@*}"
    gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:${account}" --role="$role" --quiet || true
  done
  safe="${account%@*}"
  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    STEP="delete_key_${safe}"
    gcloud iam service-accounts keys delete "$key" --iam-account="$account" \
      --quiet
  done < <(jq -r '.[].name | split("/")[-1]' "$DIR/${safe}-keys-before.json")
done

STEP=remove_rates_self_binding
gcloud iam service-accounts remove-iam-policy-binding \
  "pf-rates@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="$PROJECT_ID" \
  --member="serviceAccount:pf-rates@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role=roles/iam.serviceAccountUser --quiet || true

STEP=after
gcloud projects get-iam-policy "$PROJECT_ID" --format=json >"$DIR/project-policy-after.json"
for account in "${RUNTIME_ACCOUNTS[@]}" "$LEGACY_DEPLOYER"; do
  safe="${account%@*}"
  gcloud iam service-accounts get-iam-policy "$account" --project="$PROJECT_ID" \
    --format=json >"$DIR/${safe}-service-policy-after.json" || true
  gcloud iam service-accounts keys list --iam-account="$account" \
    --managed-by=user --format=json >"$DIR/${safe}-keys-after.json" || true
done

STEP=summary
cat >"$DIR/summary.md" <<EOF
# IMP-005 legacy IAM/key cleanup summary

- project: $PROJECT_ID
- mutations: legacy deploy grants and user-managed keys removed
- preserved: WIF deployer bindings, runtime secret accessor/cloudsql grants
- github_secret_cleanup: separate GitHub API step required
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
