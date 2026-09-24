#!/usr/bin/env bash
# ============================================================================
# pf-services.sh - start/stop/restart the local PF stack
#
# Manages the three services of the local dev environment:
#   1. pf-db      - PostgreSQL container (via pf-db's Makefile)
#   2. pf-rates   - FastAPI microservice on :8001
#   3. pf-payroll - FastAPI microservice on :8000
#
# Usage:
#   scripts/pf-services.sh start
#   scripts/pf-services.sh stop
#   scripts/pf-services.sh restart
#
# Notes:
#   - Does NOT touch any .env file — services run with whatever config
#     is already in modules/pf-rates/.env and modules/pf-payroll/.env.
#   - Logs go to scripts/logs/<service>.log (gitignored)
# ============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PF_DB_DIR="$ROOT_DIR/modules/pf-db"
PF_RATES_DIR="$ROOT_DIR/modules/pf-rates"
PF_PAYROLL_DIR="$ROOT_DIR/modules/pf-payroll"

LOG_DIR="$ROOT_DIR/scripts/logs"
mkdir -p "$LOG_DIR"

RATES_PORT=8001
PAYROLL_PORT=8000
RATES_MODULE="rates.interfaces.api.main:app"
PAYROLL_MODULE="payroll.interfaces.api.main:app"
DB_HOST="localhost"
DB_PORT=5432

# Tracks the outcome of each start-time check, printed in the final summary.
# (plain vars, not an associative array — macOS ships bash 3.2, no declare -A)
STATUS_DB=""
STATUS_RATES=""
STATUS_PAYROLL=""

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
section() { printf '\n== %s ==\n' "$*"; }
log() { printf '  %s\n' "$*"; }

is_uvicorn_running() {
  # $1 = module pattern (e.g. "rates.interfaces.api.main:app")
  pgrep -f "uvicorn $1" >/dev/null 2>&1
}

wait_for_health() {
  # $1 = url, $2 = label, $3 = max attempts (default 20, ~10s)
  local url="$1" label="$2" attempts="${3:-20}"
  for ((i = 1; i <= attempts; i++)); do
    if curl -sf "$url" >/dev/null 2>&1; then
      log "$label healthy -> $url"
      return 0
    fi
    sleep 0.5
  done
  log "WARNING: $label did not answer $url in time — check its log."
  return 1
}

wait_for_tcp() {
  # $1 = host, $2 = port, $3 = label, $4 = max attempts (default 20, ~10s)
  local host="$1" port="$2" label="$3" attempts="${4:-20}"
  for ((i = 1; i <= attempts; i++)); do
    if (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null; then
      exec 3>&- 3<&- 2>/dev/null || true
      log "$label reachable -> $host:$port"
      return 0
    fi
    sleep 0.5
  done
  log "WARNING: $label not reachable at $host:$port"
  return 1
}

wait_for_port_closed() {
  # Inverse of wait_for_tcp: confirms a port stopped accepting connections.
  # $1 = host, $2 = port, $3 = label, $4 = max attempts (default 10, ~5s)
  local host="$1" port="$2" label="$3" attempts="${4:-10}"
  for ((i = 1; i <= attempts; i++)); do
    if (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null; then
      exec 3>&- 3<&- 2>/dev/null || true
      sleep 0.5
      continue
    fi
    log "$label port closed -> $host:$port"
    return 0
  done
  log "WARNING: $label port $host:$port still accepting connections"
  return 1
}

wait_for_process_gone() {
  # Inverse of is_uvicorn_running: confirms the process actually exited
  # instead of assuming pkill worked.
  # $1 = module pattern, $2 = label, $3 = max attempts (default 10, ~5s)
  local module="$1" label="$2" attempts="${3:-10}"
  for ((i = 1; i <= attempts; i++)); do
    if ! is_uvicorn_running "$module"; then
      log "$label process gone"
      return 0
    fi
    sleep 0.5
  done
  log "WARNING: $label still running after stop attempt (try: pkill -9 -f \"uvicorn $module\")"
  return 1
}

verify_db_seed() {
  # Functional check beyond "port is open": confirms schema+seed actually
  # landed data, using the currencies seeded by db/02_seed_base.sql.
  if ! command -v psql >/dev/null 2>&1; then
    log "psql not installed locally — skipping data check (TCP check above already confirms the port is up)"
    return 0
  fi
  local count
  count=$(PGPASSWORD=pf_db psql -h "$DB_HOST" -p "$DB_PORT" -U pf_db -d pf_db \
    -tAc 'SELECT count(*) FROM "RAT_CURRENCY";' 2>/dev/null || true)
  if [[ "$count" =~ ^[0-9]+$ ]] && [ "$count" -gt 0 ]; then
    log "seed data present ($count rows in RAT_CURRENCY)"
    return 0
  fi
  log "WARNING: could not confirm seed data via psql"
  return 1
}

require_env_file() {
  # Preflight gate, called by each start_* function for its own directory.
  # Adding a new service later only means calling this from its own start
  # routine — no separate list to remember to update.
  # $1 = directory, $2 = label (for the error message)
  local dir="$1" label="$2" env_file="$1/.env"
  if [ ! -f "$env_file" ]; then
    echo ""
    echo "ERROR: $label is missing $env_file"
    echo "Create it first, e.g.: (cd $dir && make env-write), then fill in real values."
    exit 1
  fi
  log "$label .env found: $env_file"
}

start_db() {
  section "pf-db (PostgreSQL local)"
  require_env_file "$PF_DB_DIR" "pf-db"
  (cd "$PF_DB_DIR" && make local-up)
  if wait_for_tcp "$DB_HOST" "$DB_PORT" "pf-db" && verify_db_seed; then
    STATUS_DB="OK"
  else
    STATUS_DB="FAIL"
  fi
}

stop_db() {
  # $1 = status var name to set
  local status_var="$1"
  section "pf-db (PostgreSQL local)"
  (cd "$PF_DB_DIR" && make db-down) || true
  if wait_for_port_closed "$DB_HOST" "$DB_PORT" "pf-db"; then
    printf -v "$status_var" 'OK'
  else
    printf -v "$status_var" 'FAIL'
  fi
}

start_uvicorn() {
  # $1 = label, $2 = dir, $3 = module, $4 = port, $5 = status var name to set
  local label="$1" dir="$2" module="$3" port="$4" status_var="$5"
  section "$label"
  require_env_file "$dir" "$label"
  if is_uvicorn_running "$module"; then
    log "already running on port $port"
  else
    local logfile="$LOG_DIR/${label}.log"
    : >"$logfile"
    (cd "$dir" && nohup make run >"$logfile" 2>&1 &)
    log "logs: $logfile"
  fi
  if wait_for_health "http://localhost:$port/health" "$label"; then
    printf -v "$status_var" 'OK'
  else
    printf -v "$status_var" 'FAIL'
  fi
}

stop_uvicorn() {
  # $1 = label, $2 = module, $3 = status var name to set
  local label="$1" module="$2" status_var="$3"
  section "$label"
  if ! is_uvicorn_running "$module"; then
    log "was not running"
    printf -v "$status_var" 'OK'
    return 0
  fi
  pkill -f "uvicorn $module" || true
  if wait_for_process_gone "$module" "$label"; then
    printf -v "$status_var" 'OK'
  else
    printf -v "$status_var" 'FAIL'
  fi
}

# ----------------------------------------------------------------------------
# Commands
# ----------------------------------------------------------------------------
print_summary() {
  section "Summary"
  local overall=0
  printf '  %-12s %s\n' "pf-db" "${STATUS_DB:-UNKNOWN}"
  printf '  %-12s %s\n' "pf-rates" "${STATUS_RATES:-UNKNOWN}"
  printf '  %-12s %s\n' "pf-payroll" "${STATUS_PAYROLL:-UNKNOWN}"
  [ "$STATUS_DB" = "OK" ] && [ "$STATUS_RATES" = "OK" ] && [ "$STATUS_PAYROLL" = "OK" ] || overall=1
  return "$overall"
}

cmd_start() {
  start_db
  start_uvicorn "pf-rates" "$PF_RATES_DIR" "$RATES_MODULE" "$RATES_PORT" STATUS_RATES
  start_uvicorn "pf-payroll" "$PF_PAYROLL_DIR" "$PAYROLL_MODULE" "$PAYROLL_PORT" STATUS_PAYROLL
  echo ""
  echo "Tail logs with: tail -f $LOG_DIR/*.log"
  print_summary
}

cmd_stop() {
  stop_uvicorn "pf-payroll" "$PAYROLL_MODULE" STATUS_PAYROLL
  stop_uvicorn "pf-rates" "$RATES_MODULE" STATUS_RATES
  stop_db STATUS_DB
  echo ""
  print_summary
}

cmd_restart() {
  cmd_stop
  cmd_start
}

usage() {
  cat <<EOF
Usage: $(basename "$0") {start|stop|restart}

  start    Start pf-db (local Postgres), pf-rates and pf-payroll
  stop     Stop pf-payroll, pf-rates and pf-db (in that order)
  restart  stop, then start (reuses the same routines above)
EOF
  exit 1
}

case "${1:-}" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  restart) cmd_restart ;;
  *) usage ;;
esac
