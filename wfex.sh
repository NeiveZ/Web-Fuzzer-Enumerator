set -uo pipefail

VERSION="3.2.9"
TOOL_NAME="WFEX"
TOOL_TITLE="Web Fuzzer & Enumerator eXtended"

USE_COLOR=true
R=$'\e[0m'; BOLD=$'\e[1m'
RD=$'\e[91m'; GR=$'\e[92m'; YL=$'\e[93m'; BL=$'\e[94m'; DB=$'\e[34m'; DG=$'\e[90m'; CY=$'\e[96m'; WH=$'\e[97m'; MG=$'\e[95m'

WL_DIR="${WEBRECON_WORDLIST_DIR:-${HOME}/.config/wfex/wordlists}"

# Simple/default execution model. Advanced flags can override these.
URL=""
WORDLIST=""
EXTENSIONS=""
THREADS=10
TIMEOUT=8
RETRIES=0
DELAY=0
MATCH_CODES="200"
SHOW_REDIRECTS=false
ONLY_DIRS=false
ONLY_FILES=false
FOLLOW_REDIRECT=false
FALLBACK_HTTP=true
NO_PROGRESS=false
SHOW_PROGRESS=false
SHOW_SUMMARY=false
SILENT=false
LIVE_RESULTS=true
FINAL_TABLE=false
OUTPUT=""
FIXED_UA=""
UA_FILE=""
UA_MODE="random"
PROFILE="standard"
PROFILE_SET=false
EXPLICIT_THREADS=""
EXPLICIT_TIMEOUT=""
EXPLICIT_RETRIES=""
EXPLICIT_DELAY=""
START_TIME=0
TMP_DIR=""
RESULT_FILE=""
TARGET_FILE=""
DIR_TARGET_FILE=""
FILE_TARGET_FILE=""
TARGET_COUNT=0
FOUND_COUNT=0
REDIR_COUNT=0
SENSITIVE_COUNT=0
DIR_COUNT=0
FILE_COUNT=0
DONE_COUNT=0
LAST_PROGRESS=-1
DIR_HEADER_SHOWN=false
FILE_HEADER_SHOWN=false

BUILTIN_UAS=(
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/126.0.0.0 Safari/537.36"
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/125.0.0.0 Safari/537.36"
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:127.0) Gecko/20100101 Firefox/127.0"
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 Version/17.5 Safari/605.1.15"
  "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:126.0) Gecko/20100101 Firefox/126.0"
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Edg/126.0.0.0 Safari/537.36"
  "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1"
)

BUILTIN_WORDLIST=(
  admin administrator login panel dashboard upload uploads files backup backups tmp temp old test dev prog fonts site webmail
  staging stage api api-v1 api-v2 assets static public private secure auth user users account accounts
  config configuration data database db logs log reports report status health monitor monitoring metrics
  internal intranet portal adminer server servers host hosts web webadmin webmail mail email ftp sftp
  docs documentation support help api-docs swagger openapi console manage management system core app
  applications service services services-api gateway proxy reverse-proxy nginx apache tomcat jenkins
  git github gitlab docker registry k8s kubernetes grafana prometheus elastic kibana vault minio
  wordpress wp-admin wp-login wp-content phpinfo robots.txt sitemap.xml sitemap sitemap_index.xml
  .git .git/config .env .env.local .env.production .htaccess web.config composer.json package.json
  index install setup update upgrade reset register logout profile settings users permissions downloads
  media images img css js static-content source src vendor lib include includes templates views themes
  cache temp files storage backups archives oldsite old_admin devops qa uat demo beta alpha
)

# ── UI ─────────────────────────────────────────────────────────────
BOX_WIDTH=71
BLINK=$'\e[5m'

box_line() {
  $SILENT && return 0
  printf '%b|%s|%b\n' "$RD$BLINK" "$(printf '%*s' "$BOX_WIDTH" '' | tr ' ' '-')" "$R" >&2
}

box_title() {
  $SILENT && return 0
  local title="$1"
  printf '%b%s%b\n' "$RD$BLINK" "$title" "$R" >&2
}

box_row() {
  $SILENT && return 0
  local label="$1" value="$2"
  printf '  %-13s %s\n' "$label" "$value" >&2
}

clear_progress_line() {
  printf "\r%*s\r" 180 "" >&2
}

banner() {
  $SILENT && return 0
  local rows=(
    '██     ██  ███████  ███████  ██   ██'
    '██     ██  ██       ██       ╚██ ██╔╝'
    '██  █  ██  █████    █████     ╚███╔╝'
    '██ ███ ██  ██       ██        ██╔██╗'
    '███   ███  ██       ███████  ██╔╝ ██╗'
    '╚══╝ ╚══╝  ╚══════╝ ╚══════╝ ╚═╝  ╚═╝'
  )
  printf '\n' >&2
  box_line
  local row
  for row in "${rows[@]}"; do
    printf '%b%b%s%b\n' "$RD$BOLD" "$RD" "$row" "$R" >&2
  done
  printf '%bWFEX%b  |  %s\n' "$BOLD$WH" "$R" "$TOOL_TITLE" >&2
  printf '%bVersion %s  |  Precision web content discovery%b\n' "$CY" "$VERSION" "$R" >&2
  box_line
  printf '\n' >&2
}

separator() { box_line; }
section() {
  $SILENT && return 0
  local title="$1"
  box_line
  box_title "$title"
}

info_line() {
  $SILENT && return 0
  printf "  %b%-14s%b %s\n" "$CY" "$1" "$R" "$2"
}
warn() { $SILENT || printf "%b[!]%b %s\n" "$YL" "$R" "$1" >&2; }
ok() { $SILENT || printf "%b[+]%b %s\n" "$GR" "$R" "$1"; }
die() { printf "%b[!]%b %s\n" "$RD" "$R" "$1" >&2; exit 1; }

cleanup() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

# ── Generic helpers ────────────────────────────────────────────────
is_pos_int() { [[ "$1" =~ ^[0-9]+$ ]] && (( 10#$1 > 0 )); }
is_nonneg_int() { [[ "$1" =~ ^[0-9]+$ ]]; }
valid_codes() { [[ "$1" =~ ^[0-9]{3}(,[0-9]{3})*$ ]]; }

compact() {
  local v="$1" max="${2:-90}"
  if (( ${#v} > max )); then printf "%s…" "${v:0:$((max-1))}"; else printf "%s" "$v"; fi
}

urlencode_path() {
  local s="$1"
  s="${s// /%20}"
  s="${s//\[/\%5B}"; s="${s//\]/\%5D}"
  printf "%s" "$s"
}

contains_code() {
  local needle="$1" list="$2" item
  IFS=',' read -ra items <<< "$list"
  for item in "${items[@]}"; do [[ "$item" == "$needle" ]] && return 0; done
  return 1
}

add_codes() {
  local code item out=() seen
  IFS=',' read -ra codes <<< "$MATCH_CODES,$1"
  for code in "${codes[@]}"; do
    [[ -z "$code" ]] && continue
    seen=false
    for item in "${out[@]}"; do [[ "$item" == "$code" ]] && seen=true; done
    $seen || out+=("$code")
  done
  MATCH_CODES=$(IFS=,; printf '%s' "${out[*]}")
}

status_match() { contains_code "$1" "$MATCH_CODES"; }

# ── Profiles ───────────────────────────────────────────────────────
apply_profile() {
  case "$PROFILE" in
    standard) THREADS=10; TIMEOUT=8; RETRIES=0; DELAY=0 ;;
    fast) THREADS=10; TIMEOUT=5; RETRIES=0; DELAY=0 ;;
    balanced) THREADS=10; TIMEOUT=8; RETRIES=0; DELAY=0 ;;
    accurate) THREADS=10; TIMEOUT=10; RETRIES=1; DELAY=25 ;;
    *) die "Unknown profile: $PROFILE (standard, fast, balanced, accurate)" ;;
  esac
}

# ── Wordlists ──────────────────────────────────────────────────────
resolve_wordlist() {
  local input="$1"
  [[ -f "$input" ]] && { printf "%s" "$input"; return 0; }
  [[ -f "$WL_DIR/$input" ]] && { printf "%s" "$WL_DIR/$input"; return 0; }
  [[ -f "$WL_DIR/${input}.txt" ]] && { printf "%s" "$WL_DIR/${input}.txt"; return 0; }
  return 1
}

get_words() {
  if [[ -n "$WORDLIST" ]]; then
    sed 's/\r$//' "$WORDLIST" | awk 'NF && $0 !~ /^[[:space:]]*#/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); if ($0 != "") print $0}' | awk '!seen[$0]++'
  else
    printf '%s\n' "${BUILTIN_WORDLIST[@]}"
  fi
}

list_wordlists() {
  mkdir -p "$WL_DIR"
  printf "WFEX wordlists: %s\n" "$WL_DIR"
  local found=0 f
  while IFS= read -r -d '' f; do
    printf "  %-36s %s lines\n" "$(basename "$f")" "$(wc -l < "$f" 2>/dev/null || echo '?')"
    found=1
  done < <(find "$WL_DIR" -type f \( -name '*.txt' -o -name '*.lst' \) -print0 | sort -z)
  (( found == 0 )) && printf "  (none installed)\n"
}

install_wordlist() {
  local src="$1" name="${2:-$(basename "$1")}" 
  [[ -f "$src" ]] || die "Wordlist not found: $src"
  mkdir -p "$WL_DIR"
  cp "$src" "$WL_DIR/$name" || die "Unable to install wordlist"
  printf "Installed: %s\n" "$WL_DIR/$name"
}

# ── User-Agent (random by default; no CLI flag required) ──────────
get_ua() {
  if [[ -n "$FIXED_UA" ]]; then printf "%s" "$FIXED_UA"; return; fi
  local -a arr=()
  if [[ -n "$UA_FILE" ]]; then
    mapfile -t arr < <(sed 's/\r$//' "$UA_FILE" | awk 'NF && $0 !~ /^[[:space:]]*#/')
  else
    arr=("${BUILTIN_UAS[@]}")
  fi
  ((${#arr[@]})) || arr=("Mozilla/5.0")
  printf "%s" "${arr[RANDOM % ${#arr[@]}]}"
}

# ── HTTP helpers ───────────────────────────────────────────────────
initial_probe() {
  local target="$1"
  curl -k -sS -I -o /dev/null -D - --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" -H "User-Agent: $(get_ua)" "$target" 2>/dev/null || true
}

header_value() {
  local headers="$1" key="$2"
  awk -v k="${key,,}:" 'BEGIN{IGNORECASE=1} tolower($0) ~ "^"k {sub(/^[^:]*:[[:space:]]*/, ""); gsub(/\r/, ""); print; exit}' <<< "$headers"
}

header_code() { awk 'BEGIN{c=""} /^HTTP\//{c=$2} END{print c}' <<< "$1"; }

normalize_url() {
  URL="${URL%/}"
  [[ "$URL" == http://* || "$URL" == https://* ]] || URL="https://$URL"
  local headers code
  headers=$(initial_probe "$URL")
  code=$(header_code "$headers")
  if [[ -z "$code" || "$code" == "000" ]]; then
    if $FALLBACK_HTTP && [[ "$URL" == https://* ]]; then
      local http_url="${URL/https:\/\//http://}" http_headers http_code
      http_headers=$(initial_probe "$http_url")
      http_code=$(header_code "$http_headers")
      if [[ -n "$http_code" && "$http_code" != "000" ]]; then
        URL="$http_url"
        headers="$http_headers"
      fi
    fi
  fi
  printf "%s" "$headers"
}

# ── Target generation ──────────────────────────────────────────────
build_targets() {
  local word ext safe
  : > "$DIR_TARGET_FILE"
  : > "$FILE_TARGET_FILE"
  while IFS= read -r word; do
    [[ -z "$word" ]] && continue
    safe=$(urlencode_path "$word")
    if ! $ONLY_FILES; then
      printf "%s\tDIR\n" "${URL}/${safe}/" >> "$DIR_TARGET_FILE"
    fi
    if ! $ONLY_DIRS && [[ -n "$EXTENSIONS" ]]; then
      IFS=',' read -ra exts <<< "$EXTENSIONS"
      for ext in "${exts[@]}"; do
        ext="${ext//[[:space:]]/}"; ext="${ext#.}"
        [[ -n "$ext" ]] || continue
        printf "%s\tFILE\n" "${URL}/${safe}.${ext}" >> "$FILE_TARGET_FILE"
      done
    fi
  done < <(get_words)

  TARGET_COUNT=$(( $(wc -l < "$DIR_TARGET_FILE" | tr -d ' ') + $(wc -l < "$FILE_TARGET_FILE" | tr -d ' ') ))
}

# ── Findings / output ──────────────────────────────────────────────
result_label() {
  local url="$1"
  if [[ "$url" == */ ]]; then printf "DIR"; return; fi
  local ext="${url##*.}"; ext="${ext%%\?*}"; ext="${ext,,}"
  case ",$ext," in
    *,bak,*|*,old,*|*,zip,*|*,tar,*|*,gz,*|*,7z,*|*,rar,*|*,env,*|*,sql,*|*,log,*|*,conf,*|*,ini,*|*,key,*|*,pem,*|*,p12,*|*,swp,*|*,dist,*) printf "SENSITIVE" ;;
    *) printf "FILE" ;;
  esac
}

redirect_target() {
  local location="$1"
  [[ -z "$location" ]] && { printf '%s' '-'; return; }
  printf '%s' "$location"
}

print_finding() {
  local url="$1" code="$2" size="$3" redirect="$4" label="$5"
  $SILENT && return 0
  $LIVE_RESULTS || return 0

  local kind="Directory Found:"
  [[ "$label" == "FILE" || "$label" == "SENSITIVE" ]] && kind="File Found:"
  local value="$url"
  if [[ "$code" == "301" || "$code" == "302" ]] && [[ -n "$redirect" && "$redirect" != "-" ]]; then
    value="$url -> $redirect"
  fi
  value=$(compact "$value" $((BOX_WIDTH-22)))

  # Clean discovery line: no side walls, only section separators.
  printf ' %b%-17s%b %b%s%b\n' \
    "$DB$BOLD" "$kind" "$R" "$YL" "$value" "$R" >&2
}


render_progress() {
  local done="$1" total="$2" width=34 pct=0 filled=0 bar=""
  (( total > 0 )) && pct=$(( done * 100 / total ))
  (( pct > 100 )) && pct=100
  (( pct == LAST_PROGRESS )) && return 0
  LAST_PROGRESS="$pct"
  filled=$(( pct * width / 100 ))
  (( filled > width )) && filled=$width
  bar=$(printf '%*s' "$filled" '' | tr ' ' '#')
  bar="${bar}$(printf '%*s' "$((width-filled))" '' | tr ' ' '.')"
  printf "\r%bScanning%b [%s] %3d%% | %d/%d | found:%d | dirs:%d | files:%d | redirects:%d" \
    "$CY" "$R" "$bar" "$pct" "$done" "$total" "$FOUND_COUNT" "$DIR_COUNT" "$FILE_COUNT" "$REDIR_COUNT" >&2
}

process_curl_line() {
  local line="$1" url code size redirect label
  IFS=$'\t' read -r url code size redirect <<< "$line"
  [[ -z "$url" || -z "$code" ]] && return 0
  [[ "$code" =~ ^[0-9]{3}$ ]] || return 0
  label=$(result_label "$url")

  if [[ "$code" == "301" || "$code" == "302" ]]; then
    $SHOW_REDIRECTS || return 0
  fi
  status_match "$code" || return 0

  printf "%s\t%s\t%s\t%s\t%s\n" "$url" "$code" "${size:-0}" "${redirect:--}" "$label" >> "$RESULT_FILE"
  FOUND_COUNT=$((FOUND_COUNT + 1))
  [[ "$label" == "DIR" ]] && DIR_COUNT=$((DIR_COUNT + 1))
  [[ "$label" == "FILE" || "$label" == "SENSITIVE" ]] && FILE_COUNT=$((FILE_COUNT + 1))
  [[ "$code" == "301" || "$code" == "302" ]] && REDIR_COUNT=$((REDIR_COUNT + 1))
  [[ "$label" == "SENSITIVE" ]] && SENSITIVE_COUNT=$((SENSITIVE_COUNT + 1))
  print_finding "$url" "$code" "${size:-0}" "${redirect:--}" "$label"
}

# ── Parallel scan ──────────────────────────────────────────────────
phase_banner() { :; }
phase_footer() { :; }

run_scan() {
  local target_file="$1" phase_label="$2" item_label="$3"
  local total start=0 end batch_file config_file line
  total=$(wc -l < "$target_file" | tr -d ' ')
  (( total > 0 )) || {
    if ! $SILENT; then
      phase_banner "$phase_label"
      phase_footer
    fi
    return 0
  }

  if ! $SILENT; then
    phase_banner "$phase_label"
  fi

  local batch_size=$(( THREADS * 8 ))
  (( batch_size < 64 )) && batch_size=64
  (( batch_size > 256 )) && batch_size=256
  DONE_COUNT=0
  LAST_PROGRESS=-1

  while (( start < total )); do
    end=$(( start + batch_size - 1 )); (( end >= total )) && end=$(( total - 1 ))
    batch_file="$TMP_DIR/batch_${phase_label// /_}_${start}.tsv"
    config_file="$TMP_DIR/curl_${phase_label// /_}_${start}.cfg"
    sed -n "$((start+1)),$((end+1))p" "$target_file" > "$batch_file"
    : > "$config_file"

    while IFS=$'\t' read -r url _type; do
      local ua
      ua=$(get_ua)
      printf 'url = "%s"\n' "${url//\"/\\\"}" >> "$config_file"
      printf 'output = "/dev/null"\n' >> "$config_file"
      printf 'user-agent = "%s"\n' "${ua//\"/\\\"}" >> "$config_file"
      printf 'connect-timeout = %s\n' "$TIMEOUT" >> "$config_file"
      printf 'max-time = %s\n' "$TIMEOUT" >> "$config_file"
      printf 'retry = %s\n' "$RETRIES" >> "$config_file"
      printf 'retry-delay = 0\n' >> "$config_file"
      printf 'retry-max-time = %s\n' "$TIMEOUT" >> "$config_file"
      $FOLLOW_REDIRECT && printf 'location\n' >> "$config_file"
      printf 'write-out = "%%{url_effective}\\t%%{http_code}\\t%%{size_download}\\t%%{redirect_url}\\n"\n' >> "$config_file"
      printf '\n' >> "$config_file"
    done < "$batch_file"

    while IFS= read -r line; do
      DONE_COUNT=$((DONE_COUNT + 1))
      process_curl_line "$line"
      if $SHOW_PROGRESS && ! $NO_PROGRESS && ! $SILENT; then render_progress "$DONE_COUNT" "$total"; fi
    done < <(curl -k -sS --parallel --parallel-immediate --parallel-max "$THREADS" --config "$config_file" 2>/dev/null || true)

    start=$((end + 1))
  done

  DONE_COUNT="$total"
  if $SHOW_PROGRESS && ! $NO_PROGRESS && ! $SILENT; then render_progress "$DONE_COUNT" "$total"; printf "\n" >&2; fi
  if ! $SILENT; then
    phase_footer
  fi
}

# ── Presentation ──────────────────────────────────────────────────
print_target_info() {
  local headers="$1" server tech wl mode
  $SILENT && return 0
  server=$(header_value "$headers" "Server")
  tech=$(header_value "$headers" "X-Powered-By")
  wl="${WORDLIST:+$(basename "$WORDLIST")}"; [[ -n "$wl" ]] || wl="built-in"
  mode="directories"; [[ -n "$EXTENSIONS" ]] && mode="directories + files"

  box_line
  printf '%bScan configuration%b\n' "$RD$BLINK" "$R" >&2
  box_row "Target" "$URL"
  box_row "WebServer" "${server:--}"
  box_row "Technology" "${tech:--}"
  box_row "Wordlist" "$wl ($(wc -l < "$DIR_TARGET_FILE" | tr -d ' ') candidates)"
  [[ -n "$EXTENSIONS" ]] && box_row "Extensions" "$EXTENSIONS"
  box_row "Mode" "$mode"
  box_line
}

print_summary() {
  $SHOW_SUMMARY || return 0
  $SILENT && return 0
  local elapsed=$(( $(date +%s) - START_TIME ))
  box_line
  box_title "Summary"
  box_row "Found" "$FOUND_COUNT"
  box_row "Directories" "$DIR_COUNT"
  box_row "Files" "$FILE_COUNT"
  box_row "Sensitive" "$SENSITIVE_COUNT"
  box_row "Redirects" "$REDIR_COUNT"
  box_row "Requests" "$TARGET_COUNT"
  box_row "Elapsed" "${elapsed}s"
  [[ -n "$OUTPUT" ]] && box_row "Report" "$OUTPUT"
  box_line
}

print_results_table() {
  [[ -s "$RESULT_FILE" ]] || return 0
  section "Results"
  printf "  %-12s %-5s %-8s %s\n" "TYPE" "CODE" "SIZE" "PATH"
  printf "  %-12s %-5s %-8s %s\n" "------------" "-----" "--------" "------------------------------------------------------------"
  while IFS=$'\t' read -r url code size redirect label; do
    local color="$CY"; local extra=""
    [[ "$label" == "DIR" ]] && color="$GR"
    [[ "$label" == "SENSITIVE" ]] && color="$RD"
    [[ "$code" == "301" || "$code" == "302" ]] && color="$YL" && extra=" -> $(compact "$redirect" 60)"
    printf "  %b%-12s%b %-5s %-8s %s%s\n" "$color" "$label" "$R" "$code" "$size" "$(compact "$url" 90)" "$extra"
  done < "$RESULT_FILE"
}

write_report() {
  [[ -n "$OUTPUT" ]] || return 0
  mkdir -p "$(dirname "$OUTPUT")"
  {
    printf "# WFEX %s\n" "$VERSION"
    printf "# Target: %s\n" "$URL"
    printf "# Generated: %s\n\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    printf "URL\tCODE\tSIZE\tREDIRECT\tTYPE\n"
    cat "$RESULT_FILE"
  } > "$OUTPUT"
}

# ── Environment ────────────────────────────────────────────────────
check_environment() {
  banner
  local failed=0 dep cv major minor
  for dep in bash curl awk sed grep sort; do
    command -v "$dep" >/dev/null 2>&1 || { printf "%bMissing dependency: %s%b\n" "$RD" "$dep" "$R"; failed=1; }
  done
  cv=$(curl --version 2>/dev/null | awk 'NR==1{print $2}')
  major=$(cut -d. -f1 <<< "$cv"); minor=$(cut -d. -f2 <<< "$cv")
  if (( major > 7 || (major == 7 && minor >= 66) )); then
    printf "%b[+]%b curl %s\n" "$GR" "$R" "$cv"
  else
    printf "%b[!]%b curl %s — upgrade recommended\n" "$YL" "$R" "${cv:--}"
  fi
  if bash -n "$0"; then printf "%b[+]%b shell syntax: PASS\n" "$GR" "$R"; else printf "%b[!]%b shell syntax: FAIL\n" "$RD" "$R"; failed=1; fi
  (( failed == 0 )) && ok "WFEX is ready." && return 0
  return 1
}

# ── Help ───────────────────────────────────────────────────────────
usage() {
  banner
  cat << HELP
Quick use
  $0 <url>
  $0 <url> <extension|extensions>
  $0 <url> <wordlist> [extension|extensions]

Examples
  $0 https://example.com
  $0 https://example.com php
  $0 https://example.com php,js,json
  $0 https://example.com /path/wordlist.txt php

Optional controls
  --profile <name>     standard | fast | balanced | accurate
  --threads <n>        Override concurrency (advanced)
  --timeout <sec>      Override request timeout (advanced)
  --retries <n>        Override retries (advanced)
  --redirects          Show 301/302 discoveries
  --match <codes>      Replace visible status codes (default: 200)
  --no-live             Hide live findings and show the final table
  --table               Show the complete final table
  --progress             Show the progress bar (off by default)
  --summary              Show an end-of-scan summary (off by default)
  --no-progress          Hide the progress bar
  -o, --output <file>   Save the complete raw report

Wordlists
  wordlists list
  wordlists install <file> [name]

Utilities
  check
  version
  help

Notes
  User-Agent rotation is automatic. No parameter is required.
  403 and 404 are hidden by default. 301/302 can be shown with --redirects.
  With an extension, WFEX scans directories first and then files, keeping the output organized.
HELP
  exit 0
}

# ── Parse command / simple syntax ─────────────────────────────────
[[ $# -gt 0 ]] || usage

COMMAND="scan"
if [[ "$1" == "check" || "$1" == "version" || "$1" == "help" || "$1" == "--help" || "$1" == "-h" || "$1" == "wordlists" ]]; then
  COMMAND="$1"; shift
fi

if [[ "$COMMAND" == "check" ]]; then check_environment; exit $?; fi
if [[ "$COMMAND" == "version" ]]; then printf "%s %s — %s\n" "$TOOL_NAME" "$VERSION" "$TOOL_TITLE"; exit 0; fi
if [[ "$COMMAND" == "help" || "$COMMAND" == "--help" || "$COMMAND" == "-h" ]]; then usage; fi

if [[ "$COMMAND" == "wordlists" ]]; then
  action="${1:-list}"
  case "$action" in
    list) list_wordlists ;;
    install) [[ -n "${2:-}" ]] || die "Usage: $0 wordlists install <file> [name]"; install_wordlist "$2" "${3:-}" ;;
    *) die "Unknown wordlists action: $action" ;;
  esac
  exit 0
fi

# First argument is always the URL for scans.
URL="${1:-}"
[[ -n "$URL" ]] || die "URL is required. Use '$0 help'."
shift

# Optional positional argument: existing file => wordlist, otherwise => extension list.
if [[ -n "${1:-}" && "${1:0:1}" != "-" ]]; then
  if [[ -f "$1" || -f "$WL_DIR/$1" || -f "$WL_DIR/${1}.txt" ]]; then
    WORDLIST="$1"; shift
  else
    EXTENSIONS="$1"; shift
  fi
fi
if [[ -n "${1:-}" && "${1:0:1}" != "-" ]]; then
  EXTENSIONS="$1"; shift
fi

# Advanced options remain available, but are not required for normal use.
while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--wordlist) WORDLIST="${2:-}"; shift 2 ;;
    -e|--extensions|--ext) EXTENSIONS="${2:-}"; shift 2 ;;
    --threads) EXPLICIT_THREADS="${2:-}"; shift 2 ;;
    --timeout) EXPLICIT_TIMEOUT="${2:-}"; shift 2 ;;
    --retries) EXPLICIT_RETRIES="${2:-}"; shift 2 ;;
    --profile) PROFILE="${2:-}"; PROFILE_SET=true; shift 2 ;;
    --redirects|--show-redirects) SHOW_REDIRECTS=true; add_codes "301,302"; shift ;;
    --match) MATCH_CODES="${2:-}"; shift 2 ;;
    --dirs-only) ONLY_DIRS=true; shift ;;
    --files-only) ONLY_FILES=true; shift ;;
    --follow) FOLLOW_REDIRECT=true; shift ;;
    --no-fallback) FALLBACK_HTTP=false; shift ;;
    --no-live) LIVE_RESULTS=false; FINAL_TABLE=true; shift ;;
    --table|--final-table) FINAL_TABLE=true; shift ;;
    --progress) SHOW_PROGRESS=true; shift ;;
    --summary) SHOW_SUMMARY=true; shift ;;
    --no-progress) NO_PROGRESS=true; shift ;;
    --no-color) USE_COLOR=false; shift ;;
    --silent) SILENT=true; shift ;;
    --user-agent) FIXED_UA="${2:-}"; UA_MODE="custom"; shift 2 ;;
    -a|--agents) UA_FILE="${2:-}"; shift 2 ;;
    -o|--output) OUTPUT="${2:-}"; shift 2 ;;
    --list-wordlists) list_wordlists; exit 0 ;;
    --install-wordlist) [[ -n "${2:-}" ]] || die "--install-wordlist requires a file"; install_wordlist "$2" "${3:-}"; exit 0 ;;
    *) die "Unknown option: $1 (use '$0 help')" ;;
  esac
done

if [[ -n "$WORDLIST" ]]; then
  WORDLIST=$(resolve_wordlist "$WORDLIST") || die "Wordlist not found: $WORDLIST"
fi

if [[ "$USE_COLOR" == false ]]; then
  R=""; BOLD=""; RD=""; GR=""; YL=""; BL=""; DG=""; CY=""; WH=""; MG=""; BLINK=""
fi

if $PROFILE_SET; then apply_profile; fi
[[ -n "$EXPLICIT_THREADS" ]] && THREADS="$EXPLICIT_THREADS"
[[ -n "$EXPLICIT_TIMEOUT" ]] && TIMEOUT="$EXPLICIT_TIMEOUT"
[[ -n "$EXPLICIT_RETRIES" ]] && RETRIES="$EXPLICIT_RETRIES"
[[ -n "$EXPLICIT_DELAY" ]] && DELAY="$EXPLICIT_DELAY"

is_pos_int "$THREADS" || die "Invalid --threads value: $THREADS"
is_pos_int "$TIMEOUT" || die "Invalid --timeout value: $TIMEOUT"
is_nonneg_int "$RETRIES" || die "Invalid --retries value: $RETRIES"
valid_codes "$MATCH_CODES" || die "Invalid --match value: $MATCH_CODES"
[[ -n "$UA_FILE" && ! -f "$UA_FILE" ]] && die "User-Agent file not found: $UA_FILE"
$ONLY_DIRS && $ONLY_FILES && die "--dirs-only and --files-only cannot be combined"

TMP_DIR=$(mktemp -d) || die "Unable to create temporary directory"
RESULT_FILE="$TMP_DIR/results.tsv"
DIR_TARGET_FILE="$TMP_DIR/dir_targets.tsv"
FILE_TARGET_FILE="$TMP_DIR/file_targets.tsv"
TARGET_FILE="$TMP_DIR/targets.tsv"
touch "$RESULT_FILE"

START_TIME=$(date +%s)
INIT_HEADERS=$(normalize_url)
INIT_CODE=$(header_code "$INIT_HEADERS")

if $ONLY_DIRS; then EXTENSIONS=""; fi
if $ONLY_FILES && [[ -z "$EXTENSIONS" ]]; then EXTENSIONS="php,html,js,json,txt,bak,env"; fi
if [[ -n "$EXTENSIONS" ]]; then ONLY_FILES=false; ONLY_DIRS=false; fi

build_targets
DIR_COUNT_TARGET=$(wc -l < "$DIR_TARGET_FILE" | tr -d ' ')
FILE_COUNT_TARGET=$(wc -l < "$FILE_TARGET_FILE" | tr -d ' ')
TARGET_COUNT=$((DIR_COUNT_TARGET + FILE_COUNT_TARGET))
(( TARGET_COUNT > 0 )) || die "No scan candidates were generated"

if [[ "$USE_COLOR" == false ]]; then
  R=""; BOLD=""; RD=""; GR=""; YL=""; BL=""; DG=""; CY=""; WH=""; MG=""; BLINK=""
fi

if ! $SILENT; then
  banner
  print_target_info "$INIT_HEADERS"
fi

# Reset counters between phases only for progress, not findings.
if (( DIR_COUNT_TARGET > 0 )); then
  run_scan "$DIR_TARGET_FILE" "Directories Found" "Directory Found"
fi
if (( DIR_COUNT_TARGET > 0 && FILE_COUNT_TARGET > 0 )) && ! $SILENT; then
  box_line
fi
if (( FILE_COUNT_TARGET > 0 )); then
  run_scan "$FILE_TARGET_FILE" "Files Found" "File Found"
fi
if ! $SILENT; then
  box_line
fi

if $FINAL_TABLE && ! $SILENT; then
  print_results_table
fi
write_report
print_summary
exit 0
