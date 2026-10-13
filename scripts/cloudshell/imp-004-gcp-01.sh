#!/usr/bin/env bash
set -euo pipefail
umask 077

PROJECT_ID="coreassistant-474022"
REGION="us-central1"
ID="imp-004"
N="01"
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
printf 'project=%s\nregion=%s\nmutations=none\nsecrets=values-not-read\n' "$PROJECT_ID" "$REGION" >"$DIR/context.txt"

STEP=secret-policies
for secret in PF_RATES_DATABASE_URL PF_DATABASE_URL; do
  gcloud secrets get-iam-policy "$secret" --project="$PROJECT_ID" --format=json \
    | jq '{bindings: [.bindings[]? | {role, members}]}' >"$DIR/${secret}-iam-policy.json"
done

STEP=cloud-run
gcloud run services describe pf-rates --project="$PROJECT_ID" --region="$REGION" --format=json \
  | jq '{metadata: {name: .metadata.name, generation: .metadata.generation},
         latestReadyRevision: .status.latestReadyRevisionName,
         traffic: .status.traffic,
         env: [.spec.template.spec.containers[]?.env[]?
           | select(.name | test("DATABASE_URL|PF_RATES"))
           | if .valueFrom.secretKeyRef then
               {name, secret: .valueFrom.secretKeyRef.name, version: .valueFrom.secretKeyRef.key}
             else {name, source: "literal-or-empty"} end]}' \
  >"$DIR/pf-rates-service.json"

STEP=summary
cat >"$DIR/summary.md" <<EOF
# Summary

- project: $PROJECT_ID
- region: $REGION
- mutations: none
- secret values: not read
- queries: Secret Manager IAM policy for PF_RATES_DATABASE_URL and PF_DATABASE_URL; Cloud Run pf-rates metadata
- expected decision input: whether the pf-rates runtime identity remains bound to the legacy shared secret
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
