#!/usr/bin/env bash
set -euo pipefail
umask 077

PROJECT_ID="coreassistant-474022"
SECRET="PF_DATABASE_URL"
MEMBER="serviceAccount:pf-rates@coreassistant-474022.iam.gserviceaccount.com"
ROLE="roles/secretmanager.secretAccessor"
ID="imp-004"
N="03"
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
BASE="$PWD"
RUN="${ID}-gcp-${N}-$(date -u +%Y%m%dT%H%M%SZ)"
DIR="$BASE/$RUN"
ARCHIVE="$BASE/$RUN.tar.gz"
STEP=init

fail() {
  status=$?
  if [[ -d "$DIR" ]]; then
    printf 'status=failed step=%s exit_code=%s\n' "$STEP" "$status" >"$DIR/failure.txt"
  fi
  printf 'status=failed step=%s exit_code=%s\n' "$STEP" "$status" >&2
  exit "$status"
}
trap fail ERR

command -v gcloud >/dev/null || { printf 'gcloud is required\n' >&2; exit 1; }
command -v jq >/dev/null || { printf 'jq is required\n' >&2; exit 1; }
command -v tar >/dev/null || { printf 'tar is required\n' >&2; exit 1; }
[[ "$PROJECT_ID" == "coreassistant-474022" ]] || { printf 'unexpected PROJECT_ID\n' >&2; exit 2; }
mkdir -m 700 "$DIR"

STEP=project
gcloud projects describe "$PROJECT_ID" --format=json >"$DIR/project.json"
STEP=session
gcloud auth list --filter=status:ACTIVE --format='value(account)' >"$DIR/session.txt"
grep -q . "$DIR/session.txt"
printf 'project=%s\nsecret=%s\nrole=%s\nmember=%s\n' "$PROJECT_ID" "$SECRET" "$ROLE" "$MEMBER" >"$DIR/context.txt"

STEP=before-policy
gcloud secrets get-iam-policy "$SECRET" --project="$PROJECT_ID" --format=json \
  | jq '{bindings: [.bindings[]? | {role, members}]}' >"$DIR/before-policy.json"
jq -e --arg role "$ROLE" --arg member "$MEMBER" \
  '.bindings[] | select(.role == $role) | .members[] | select(. == $member)' \
  "$DIR/before-policy.json" >/dev/null
jq -e --arg role "$ROLE" \
  '.bindings[] | select(.role == $role) | .members[] | select(. == "serviceAccount:pf-payroll@coreassistant-474022.iam.gserviceaccount.com")' \
  "$DIR/before-policy.json" >/dev/null

printf 'About to remove only %s from %s (%s).\n' "$MEMBER" "$SECRET" "$ROLE"
read -r -p 'Type y to continue: ' confirmation
[[ "$confirmation" == "y" || "$confirmation" == "Y" ]] || { printf 'mutation cancelled\n'; exit 0; }

STEP=mutation
gcloud secrets remove-iam-policy-binding "$SECRET" \
  --project="$PROJECT_ID" \
  --member="$MEMBER" \
  --role="$ROLE" \
  --quiet >"$DIR/mutation.txt"

STEP=after-policy
gcloud secrets get-iam-policy "$SECRET" --project="$PROJECT_ID" --format=json \
  | jq '{bindings: [.bindings[]? | {role, members}]}' >"$DIR/after-policy.json"
if jq -e --arg role "$ROLE" --arg member "$MEMBER" \
  '.bindings[] | select(.role == $role) | .members[] | select(. == $member)' \
  "$DIR/after-policy.json" >/dev/null; then
  printf 'removed_member_still_present=true\n' >"$DIR/verification.txt"
  exit 1
fi
jq -e --arg role "$ROLE" \
  '.bindings[] | select(.role == $role) | .members[] | select(. == "serviceAccount:pf-payroll@coreassistant-474022.iam.gserviceaccount.com")' \
  "$DIR/after-policy.json" >/dev/null
printf 'removed_member_present=false\npayroll_member_present=true\n' >"$DIR/verification.txt"

STEP=summary
cat >"$DIR/summary.md" <<EOF
# Summary

- project: $PROJECT_ID
- secret policy changed: $SECRET
- role: $ROLE
- removed member: $MEMBER
- preserved consumer: serviceAccount:pf-payroll@coreassistant-474022.iam.gserviceaccount.com
- secret values: not read
- mutation: completed after interactive confirmation
- verification: removed member absent; pf-payroll member present
- rollback: re-add the removed member with gcloud secrets add-iam-policy-binding
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
