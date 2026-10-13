#!/usr/bin/env bash
set -euo pipefail
umask 077

PROJECT_ID="coreassistant-474022"
ID="imp-005"
N="03"
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
  --format='json(projectId,projectNumber,lifecycleState,name,parent)' >"$DIR/project.json"

STEP=session
gcloud auth list --filter=status:ACTIVE --format='value(account)' >"$DIR/session.txt"
grep -q . "$DIR/session.txt"

STEP=ancestors
gcloud projects get-ancestors "$PROJECT_ID" --format=json >"$DIR/ancestors.json"

STEP=project_policies
gcloud org-policies list --project="$PROJECT_ID" --format=json \
  >"$DIR/project-org-policies.json"

STEP=organization_policies
: >"$DIR/organization-org-policies.jsonl"
while IFS= read -r organization; do
  [[ -n "$organization" ]] || continue
  if gcloud org-policies list --organization="$organization" --format=json \
      >"$DIR/organization-${organization}-org-policies.json" 2>"$DIR/organization-${organization}.error"; then
    jq --arg organization "$organization" \
      '{ancestor: ("organizations/" + $organization), policies: .}' \
      "$DIR/organization-${organization}-org-policies.json" \
      >>"$DIR/organization-org-policies.jsonl"
  else
    printf '{"ancestor":"organizations/%s","status":"inaccessible"}\n' "$organization" \
      >>"$DIR/organization-org-policies.jsonl"
  fi
done < <(jq -r '.[] | select(.type == "organization") | .id' "$DIR/ancestors.json")

STEP=folder_policies
: >"$DIR/folder-org-policies.jsonl"
while IFS= read -r folder; do
  [[ -n "$folder" ]] || continue
  if gcloud org-policies list --folder="$folder" --format=json \
      >"$DIR/folder-${folder}-org-policies.json" 2>"$DIR/folder-${folder}.error"; then
    jq --arg folder "$folder" \
      '{ancestor: ("folders/" + $folder), policies: .}' \
      "$DIR/folder-${folder}-org-policies.json" \
      >>"$DIR/folder-org-policies.jsonl"
  else
    printf '{"ancestor":"folders/%s","status":"inaccessible"}\n' "$folder" \
      >>"$DIR/folder-org-policies.jsonl"
  fi
done < <(jq -r '.[] | select(.type == "folder") | .id' "$DIR/ancestors.json")

STEP=summary
cat >"$DIR/summary.md" <<EOF
# IMP-005 WIF organization-policy inventory summary

- project: $PROJECT_ID
- mutations: none
- secrets_recorded: false
- private_keys_recorded: false
- raw_business_data_recorded: false
- queries: project metadata, ancestors, project/folder/organization org policies
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
