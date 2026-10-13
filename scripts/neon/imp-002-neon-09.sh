#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=pf-neon-script-base.sh
source "$SCRIPT_DIR/pf-neon-script-base.sh"

neon_init "imp-002" "09"
neon_validate_context
neon_validate_connection
neon_prepare_pgpass

STEP=preflight
neon_run_readonly "mutation-preflight" "SELECT current_user, COALESCE((SELECT rolcreaterole FROM pg_roles WHERE rolname=current_user),false) AS can_create_role, EXISTS (SELECT 1 FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member JOIN pg_roles granted ON granted.oid=m.roleid WHERE member.rolname=current_user AND granted.rolname='neon_superuser' AND m.admin_option) AS can_admin_neon_superuser, EXISTS (SELECT 1 FROM pg_roles WHERE rolname='neondb_owner') AS neondb_owner_exists, EXISTS (SELECT 1 FROM pg_roles WHERE rolname='pf_schema_owner') AS schema_owner_exists"
IFS=',' read -r current_user can_create_role can_admin_neon_superuser neondb_owner_exists schema_owner_exists < <(awk -F',' '$2 ~ /^(t|f)$/ && $3 ~ /^(t|f)$/ && $4 ~ /^(t|f)$/ && $5 ~ /^(t|f)$/ { print; exit }' "$WORK_DIR/mutation-preflight.csv")
if [[ "$can_create_role" != t || "$can_admin_neon_superuser" != t || "$neondb_owner_exists" != t ]]; then
  neon_summary_line '- mutation: not attempted; administrative preconditions are missing'
  neon_summary_line "- current_user: $current_user"
  neon_summary_line "- can_create_role: $can_create_role"
  neon_summary_line "- can_admin_neon_superuser: $can_admin_neon_superuser"
  printf 'mutation_precondition_failed=true current_user=%s can_create_role=%s can_admin_neon_superuser=%s neondb_owner_exists=%s\n' \
    "$current_user" "$can_create_role" "$can_admin_neon_superuser" "$neondb_owner_exists" >&2
  printf '%s\n' 'Use a Neon administrative connection with CREATEROLE and ADMIN OPTION on neon_superuser.' >&2
  exit 3
fi

STEP=before
neon_run_readonly "roles-before" "SELECT rolname,rolcanlogin,rolsuper,rolcreatedb,rolcreaterole,rolbypassrls FROM pg_roles WHERE rolname IN ('neon_service','neondb_owner','neon_superuser','pf_schema_owner') ORDER BY rolname"
neon_run_readonly "memberships-before" "SELECT member.rolname AS member, parent.rolname AS granted_role FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member JOIN pg_roles parent ON parent.oid=m.roleid WHERE member.rolname IN ('neon_service','neondb_owner') OR parent.rolname IN ('neon_service','neondb_owner','neon_superuser') ORDER BY member,granted_role"
neon_run_readonly "ownership-before" "SELECT n.nspname AS schema_name,c.relname AS object_name,c.relkind,owner.rolname AS owner FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_roles owner ON owner.oid=c.relowner WHERE n.nspname='public' AND owner.rolname='neondb_owner' ORDER BY c.relkind,c.relname"

printf '%s\n' 'Planned mutations:'
printf '%s\n' '- revoke neon_service membership in neon_superuser'
printf '%s\n' '- set neon_service NOLOGIN; retain role for audit/rollback'
printf '%s\n' '- create or harden pf_schema_owner as NOLOGIN and non-privileged'
printf '%s\n' '- reassign objects owned by neondb_owner to pf_schema_owner'
printf '%s\n' '- retain neondb_owner; no table/data/RLS changes'
printf '%s' 'Continue with Neon role/ownership mutations? [y/N] '
read -r answer
[[ "$answer" == y || "$answer" == Y ]]

STEP=mutation
psql --dbname="$DATABASE" --no-password --no-psqlrc --set=ON_ERROR_STOP=1 <<'SQL'
BEGIN;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pf_schema_owner') THEN
    CREATE ROLE pf_schema_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
  ELSE
    ALTER ROLE pf_schema_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
  END IF;
END
$$;
REVOKE neon_superuser FROM neon_service;
ALTER ROLE neon_service NOLOGIN;
REASSIGN OWNED BY neondb_owner TO pf_schema_owner;
COMMIT;
SQL

STEP=after
neon_run_readonly "roles-after" "SELECT rolname,rolcanlogin,rolsuper,rolcreatedb,rolcreaterole,rolbypassrls FROM pg_roles WHERE rolname IN ('neon_service','neondb_owner','neon_superuser','pf_schema_owner') ORDER BY rolname"
neon_run_readonly "memberships-after" "SELECT member.rolname AS member, parent.rolname AS granted_role FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member JOIN pg_roles parent ON parent.oid=m.roleid WHERE member.rolname IN ('neon_service','neondb_owner') OR parent.rolname IN ('neon_service','neondb_owner','neon_superuser') ORDER BY member,granted_role"
neon_run_readonly "ownership-after" "SELECT n.nspname AS schema_name,c.relname AS object_name,c.relkind,owner.rolname AS owner FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_roles owner ON owner.oid=c.relowner WHERE n.nspname='public' AND owner.rolname IN ('neondb_owner','pf_schema_owner') ORDER BY owner.rolname,c.relkind,c.relname"
neon_summary_line '- mutation: role membership/login and ownership reassignment only'
neon_summary_line '- data/schema/RLS changes: none'
neon_summary_line '- neondb_owner: retained'
neon_summary_line '- credentials_recorded: false'
neon_summary_line '- raw_business_data_recorded: false'
printf 'status=completed results=%s\n' "$WORK_DIR"
