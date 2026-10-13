#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=pf-neon-script-base.sh
source "$SCRIPT_DIR/pf-neon-script-base.sh"

neon_init "imp-002" "13"
neon_validate_context
neon_validate_connection
neon_prepare_pgpass

STEP=preflight
neon_run_readonly "admin-preflight" "SELECT current_user, COALESCE((SELECT rolsuper FROM pg_roles WHERE rolname=current_user),false) AS is_superuser, EXISTS (SELECT 1 FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member JOIN pg_roles granted ON granted.oid=m.roleid WHERE member.rolname=current_user AND granted.rolname='neon_superuser' AND m.admin_option) AS can_admin_neon_superuser, EXISTS (SELECT 1 FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member JOIN pg_roles granted ON granted.oid=m.roleid WHERE member.rolname=current_user AND granted.rolname='neon_service' AND m.admin_option) AS can_admin_neon_service"
IFS=',' read -r current_user is_superuser can_admin_neon_superuser can_admin_neon_service < <(awk -F',' '$2 ~ /^(t|f)$/ && $3 ~ /^(t|f)$/ && $4 ~ /^(t|f)$/ { print; exit }' "$WORK_DIR/admin-preflight.csv")
if [[ "$is_superuser" != t && "$can_admin_neon_superuser" != t && "$can_admin_neon_service" != t ]]; then
  neon_summary_line '- mutation: not attempted; current role lacks administrative role options'
  printf 'mutation_precondition_failed=true current_user=%s is_superuser=%s can_admin_neon_superuser=%s can_admin_neon_service=%s\n' \
    "$current_user" "$is_superuser" "$can_admin_neon_superuser" "$can_admin_neon_service" >&2
  printf '%s\n' 'Use a Neon administrative/provider connection.' >&2
  exit 3
fi

STEP=before
neon_run_readonly "roles-before" "SELECT rolname,rolcanlogin,rolsuper FROM pg_roles WHERE rolname IN ('neon_service','neon_superuser') ORDER BY rolname"
neon_run_readonly "membership-before" "SELECT member.rolname AS member, parent.rolname AS granted_role, m.admin_option FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member JOIN pg_roles parent ON parent.oid=m.roleid WHERE member.rolname='neon_service' AND parent.rolname='neon_superuser'"

printf '%s\n' 'Planned mutations:'
printf '%s\n' '- set neon_service NOLOGIN'
printf '%s\n' '- revoke neon_superuser from neon_service'
printf '%s' 'Continue with final administrative Neon cleanup? [y/N] '
read -r answer
[[ "$answer" == y || "$answer" == Y ]]

STEP=mutation
psql --dbname="$DATABASE" --no-password --no-psqlrc --set=ON_ERROR_STOP=1 <<'SQL'
BEGIN;
ALTER ROLE neon_service NOLOGIN;
REVOKE neon_superuser FROM neon_service;
COMMIT;
SQL

STEP=after
neon_run_readonly "roles-after" "SELECT rolname,rolcanlogin,rolsuper FROM pg_roles WHERE rolname IN ('neon_service','neon_superuser') ORDER BY rolname"
neon_run_readonly "membership-after" "SELECT member.rolname AS member, parent.rolname AS granted_role, m.admin_option FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member JOIN pg_roles parent ON parent.oid=m.roleid WHERE member.rolname='neon_service' AND parent.rolname='neon_superuser'"
neon_summary_line '- mutation: neon_service NOLOGIN and neon_superuser membership revoked'
neon_summary_line '- data/schema/RLS changes: none'
neon_summary_line '- credentials_recorded: false'
neon_summary_line '- raw_business_data_recorded: false'
printf 'status=completed results=%s\n' "$WORK_DIR"
