#!/usr/bin/env bash
# Run Hydra against a host list using every SecLists *betterdefaultpasslist* combo file.
# Intended for authorized security assessments only (systems you own or have permission to test).
set -euo pipefail

SECLISTS_DEFAULT_CREDENTIALS="${SECLISTS_DEFAULT_CREDENTIALS:-/usr/share/seclists/Passwords/Default-Credentials}"
HYDRA_BIN="${HYDRA_BIN:-hydra}"
# Parallel tasks; lower values reduce "[ERROR] children crashed!" (Hydra child SIGSEGVs). 0 = omit -t (Hydra default).
HYDRA_TASKS="${HYDRA_TASKS:-4}"
TOMCAT_PORT="${TOMCAT_PORT:-8080}"
DRY_RUN=0
HYDRA_FAILS=0
INCLUDE_BASE64=0
EXTRA_HYDRA_OPTS=()
OUTPUT_DIR=""
TARGETS_FILE=""

usage() {
  cat <<'EOF'
Usage: hydra-betterdefaults.sh [options] <targets.txt>

  <targets.txt>   One target per line (IPs or hostnames), same as Hydra -M.

Options:
  -d, --dry-run           Print hydra commands; do not run.
  -s, --seclists-dir DIR  Directory to search (default: SECLISTS_DEFAULT_CREDENTIALS).
  -o, --output-dir DIR    Pass -o <file> per list under this directory.
  -e, --extra HYDRA_OPTS  Extra args for every run (quote once; can repeat).
      --include-base64    Also use tomcat *_base64encoded* lists (usually not useful for -C).
  -h, --help              Show this help.

Environment:
  SECLISTS_DEFAULT_CREDENTIALS  Default-Credentials folder (Kali: .../seclists/Passwords/Default-Credentials).
  HYDRA_BIN                     Path to hydra (default: hydra).
  HYDRA_TASKS                   Parallel tasks (default: 4). Set 0 to use Hydra default. Add -e "-t N" to override.
  TOMCAT_PORT                   Port for Tomcat http-get-form scans (default: 8080).

Example:
  ./hydra-betterdefaults.sh -e "-f" -o ./hydra-out targets.txt
EOF
}

log() { printf '%s\n' "$*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -d|--dry-run) DRY_RUN=1; shift ;;
    --include-base64) INCLUDE_BASE64=1; shift ;;
    -s|--seclists-dir) SECLISTS_DEFAULT_CREDENTIALS="$2"; shift 2 ;;
    -o|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    -e|--extra)
      # shellcheck disable=SC2206
      EXTRA_HYDRA_OPTS+=($2)
      shift 2
      ;;
    --) shift; break ;;
    -*)
      log "Unknown option: $1"
      usage
      exit 2
      ;;
    *)
      if [[ -n "$TARGETS_FILE" ]]; then
        log "Unexpected argument: $1"
        exit 2
      fi
      TARGETS_FILE="$1"
      shift
      ;;
  esac
done

if [[ -z "$TARGETS_FILE" ]]; then
  log "Error: targets file is required."
  usage
  exit 2
fi

if [[ ! -f "$TARGETS_FILE" ]]; then
  log "Error: targets file not found: $TARGETS_FILE"
  exit 1
fi

if [[ ! -d "$SECLISTS_DEFAULT_CREDENTIALS" ]]; then
  log "Error: SecLists directory not found: $SECLISTS_DEFAULT_CREDENTIALS"
  exit 1
fi

if ! command -v "$HYDRA_BIN" &>/dev/null; then
  log "Error: hydra not found ($HYDRA_BIN). Install hydra or set HYDRA_BIN."
  exit 1
fi

if [[ -n "$OUTPUT_DIR" ]]; then
  mkdir -p "$OUTPUT_DIR"
fi

# Returns 0 if the combo file should be used.
filter_combo_file() {
  local base="$1"
  if [[ "$INCLUDE_BASE64" -eq 0 ]] && [[ "$base" == *"_base64encoded"* ]]; then
    return 1
  fi
  return 0
}

# prefix from e.g. ftp-betterdefaultpasslist.txt -> ftp
prefix_from_basename() {
  local b="$1"
  b="${b%.txt}"
  b="${b%_base64encoded}"
  b="${b%-betterdefaultpasslist}"
  printf '%s' "$b"
}

run_hydra() {
  local combo="$1"
  shift
  local -a cmd=("$HYDRA_BIN" -C "$combo" -M "$TARGETS_FILE")
  if [[ -n "$HYDRA_TASKS" && "$HYDRA_TASKS" != "0" ]]; then
    cmd+=(-t "$HYDRA_TASKS")
  fi
  cmd+=("${EXTRA_HYDRA_OPTS[@]}")
  if [[ -n "$OUTPUT_DIR" ]]; then
    local safe
    safe=$(basename "$combo" .txt)
    safe=${safe//[^a-zA-Z0-9._-]/_}
    cmd+=(-o "$OUTPUT_DIR/${safe}.txt")
  fi
  cmd+=("$@")
  log "+ ${cmd[*]}"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    local ec=0
    set +e
    "${cmd[@]}"
    ec=$?
    set -e
    if (( ec != 0 )); then
      ((HYDRA_FAILS++)) || true
      log "[WARN] hydra failed (exit $ec) for $(basename "$combo") — if you saw \"children crashed! (N)\", that is a Hydra worker SIGSEGV (N = worker slot). Try HYDRA_TASKS=2 or -e \"-t 2\". See README."
    fi
  fi
}

map_run() {
  local combo="$1"
  local base prefix
  base=$(basename "$combo")
  if ! filter_combo_file "$base"; then
    log "Skipping (use --include-base64 to try): $combo"
    return 0
  fi
  prefix=$(prefix_from_basename "$base")

  case "$prefix" in
    ftp)      run_hydra "$combo" ftp ;;
    ssh)      run_hydra "$combo" ssh ;;
    telnet)   run_hydra "$combo" telnet ;;
    vnc)      run_hydra "$combo" vnc ;;
    mysql)    run_hydra "$combo" mysql ;;
    mssql)    run_hydra "$combo" mssql ;;
    postgres) run_hydra "$combo" postgres ;;
    oracle)   run_hydra "$combo" oracle ;;
    windows)  run_hydra "$combo" smb ;;
    tomcat)
      # Tomcat manager HTML form (adjust path/port if your targets differ).
      run_hydra "$combo" -s "$TOMCAT_PORT" http-get-form \
        "/manager/html:j_username=^USER^&j_password=^PASS^:F=401"
      ;;
    db2)
      log "Skipping $combo: THC-Hydra has no db2 module; test DB2 with a DB-aware tool."
      ;;
    *)
      log "Skipping $combo: no built-in mapping for prefix '$prefix' (edit the script case to add one)."
      ;;
  esac
}

mapfile -t combo_files < <(
  find "$SECLISTS_DEFAULT_CREDENTIALS" -maxdepth 1 -type f \
    -iname '*betterdefaultpasslist*' ! -iname '*.md' | LC_ALL=C sort
)

if [[ ${#combo_files[@]} -eq 0 ]]; then
  log "No *betterdefaultpasslist* files under: $SECLISTS_DEFAULT_CREDENTIALS"
  exit 1
fi

log "Using ${#combo_files[@]} list(s) from $SECLISTS_DEFAULT_CREDENTIALS"
log "Targets: $TARGETS_FILE"
log "---"

for f in "${combo_files[@]}"; do
  map_run "$f" || true
done

log "---"
if [[ "$DRY_RUN" -eq 0 && "$HYDRA_FAILS" -gt 0 ]]; then
  log "Summary: $HYDRA_FAILS hydra run(s) exited non-zero."
fi
log "Done."
