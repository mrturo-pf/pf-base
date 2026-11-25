#!/usr/bin/env bash
# Migrate pf-svc-reference Secret Manager resources to their current names.
# Run this from Cloud Shell or another GCP-perimeter-authorized environment.
# No VPN is required when the execution environment is inside the perimeter.
# Secret values are streamed between gcloud commands and never printed.

set -euo pipefail

PROJECT_ID=""
RUNTIME_SERVICE_ACCOUNT="pf-svc-reference@coreassistant-474022.iam.gserviceaccount.com"
FORCE=0

SECRET_PAIRS=(
  "PF_REFERENCE_DATABASE_URL:PF_SVC_REFERENCE_DATABASE_URL"
  "PF_REFERENCE_API_KEY:PF_SVC_REFERENCE_API_KEY"
  "PF_REFERENCE_GDRIVE_EXPORT_FOLDER_ID:PF_SVC_REFERENCE_GDRIVE_EXPORT_FOLDER_ID"
)

usage() {
  cat <<'EOF'
Usage:
  migrate-pf-svc-reference-secrets.sh --project PROJECT_ID [--force]

Purpose:
  Copy the latest version of the legacy pf-svc-reference secrets into the
  current Secret Manager names and grant the runtime service account access.

Options:
  --project PROJECT_ID  GCP project that owns the secrets. Required.
  --force               Add a new version to an existing destination secret.
                        Without this flag, an existing destination is rejected.
  -h, --help            Show this help.

Safety:
  - Run only from Cloud Shell or another environment authorized by VPC Service Controls.
  - Secret values are never printed, logged, or written to local files.
  - The source secrets are not deleted or changed.
  - Review the output and deploy only after all migrations complete successfully.
EOF
}

error() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || error "required command not found: $1"
}

secret_exists() {
  local secret_name="$1"
  gcloud secrets describe "$secret_name" \
    --project="$PROJECT_ID" \
    --format='value(name)' >/dev/null 2>&1
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --project)
        (($# >= 2)) || error "--project requires a value"
        PROJECT_ID="$2"
        shift 2
        ;;
      --force)
        FORCE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error "unknown argument: $1"
        ;;
    esac
  done

  [[ -n "$PROJECT_ID" ]] || error "--project is required"
}

verify_identity() {
  local active_project
  active_project=$(gcloud config get-value project 2>/dev/null || true)
  if [[ "$active_project" != "$PROJECT_ID" ]]; then
    printf 'Active gcloud project: %s\n' "${active_project:-unset}"
    printf 'Requested project: %s\n' "$PROJECT_ID"
    error "configure the requested project first: gcloud config set project $PROJECT_ID"
  fi

  gcloud projects describe "$PROJECT_ID" --format='value(projectId)' >/dev/null \
    || error "cannot access project: $PROJECT_ID"
}

create_destination_if_needed() {
  local destination="$1"
  if secret_exists "$destination"; then
    if ((FORCE == 0)); then
      error "destination secret already exists: $destination (use --force to add a version)"
    fi
    printf 'Destination exists; a new version will be added: %s\n' "$destination"
    return 0
  fi

  gcloud secrets create "$destination" \
    --project="$PROJECT_ID" \
    --replication-policy=automatic \
    --quiet >/dev/null
  printf 'Created destination secret: %s\n' "$destination"
}

copy_latest_version() {
  local source="$1" destination="$2"
  gcloud secrets versions access latest \
    --secret="$source" \
    --project="$PROJECT_ID" \
    | gcloud secrets versions add "$destination" \
        --data-file=- \
        --project="$PROJECT_ID" \
        --quiet >/dev/null
  printf 'Copied latest version: %s -> %s\n' "$source" "$destination"
}

grant_runtime_access() {
  local destination="$1"
  gcloud secrets add-iam-policy-binding "$destination" \
    --project="$PROJECT_ID" \
    --member="serviceAccount:$RUNTIME_SERVICE_ACCOUNT" \
    --role='roles/secretmanager.secretAccessor' \
    --quiet >/dev/null
  printf 'Granted runtime access: %s -> %s\n' "$RUNTIME_SERVICE_ACCOUNT" "$destination"
}

migrate_pair() {
  local pair="$1" source destination
  source="${pair%%:*}"
  destination="${pair#*:}"

  secret_exists "$source" || error "source secret does not exist: $source"
  create_destination_if_needed "$destination"
  copy_latest_version "$source" "$destination"
  grant_runtime_access "$destination"
}

main() {
  parse_args "$@"
  require_command gcloud
  verify_identity

  printf 'Project: %s\n' "$PROJECT_ID"
  printf 'Runtime service account: %s\n' "$RUNTIME_SERVICE_ACCOUNT"
  printf 'Migrating %d secret resources without printing values.\n' "${#SECRET_PAIRS[@]}"

  local pair
  for pair in "${SECRET_PAIRS[@]}"; do
    migrate_pair "$pair"
  done

  printf '\nMigration completed. Source secrets were retained.\n'
  printf 'Next step: rerun the pf-svc-reference deployment after reviewing IAM.\n'
}

main "$@"
