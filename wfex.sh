#!/usr/bin/env bash
# WFEX - Web Fuzzer & Enumerator eXtended
# Author: NeiveZ | github.com/NeiveZ/WFEX
# Updated: no-bc dependency, safer delay handling, HTTP fallback, cleaner validation.
# For authorized security testing only.

set -uo pipefail

# ── Colors ────────────────────────────────────────────────────────
USE_COLOR=true
R="\e[0m"; BOLD="\e[1m"
RD="\e[91m"; GR="\e[92m"; YL="\e[93m"; BL="\e[94m"; DG="\e[90m"; CY="\e[96m"

colorize() {
  $USE_COLOR || { printf "%s" "$2"; return; }
  printf "%b%s%b" "$1" "$2" "$R"
}

# ── Wordlist directory ────────────────────────────────────────────
WL_DIR="${WEBRECON_WORDLIST_DIR:-${HOME}/.config/webrecon/wordlists}"

# ── Defaults ──────────────────────────────────────────────────────
URL=""
WORDLIST=""
OUTPUT=""
THREADS=20
TIMEOUT=8
DELAY=0
SILENT=false
ONLY_DIRS=false
ONLY_FILES=false
FOLLOW_REDIRECT=false
FALLBACK_HTTP=true
NO_PROGRESS=false
CLEAN_OUTPUT=true
SHOW_HEADER=true
EXTENSIONS="php,html,js,txt,bak,old,zip,json,xml,sql,env"
INTERESTING="bak,old,zip,env,sql,log,conf,key,pem"
UA_FILE=""
CODES="200,204,301,302,403,500"
TMP_DIR=""
RESULT_FILE=""

BUILTIN_UAS=(
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/119.0.0.0 Safari/537.36"
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_5) AppleWebKit/605.1.15 Version/17.0 Safari/605.1.15"
  "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0"
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Edg/120.0.2210.61 Safari/537.36"
  "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1"
  "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36"
  "Googlebot/2.1 (+http://www.google.com/bot.html)"
  "curl/7.88.1"
)

BUILTIN_WORDLIST=(
  admin login panel dashboard upload uploads files backup backups tmp temp old test dev staging api
  assets static public private secure auth user users account config data logs .git .env wp-admin
  wp-login.php phpinfo.php robots.txt sitemap.xml .htaccess web.config index install setup update
  reset register logout profile settings core system lib vendor src app docs support marketing
  reports monitor status intranet portal mail webmail ftp devops api-docs swagger
)


tool_banner() {
  ${SILENT:-false} && return 0
  cat <<'EOF'
 _       __________________  __
| |     / / ____/ ____/  |/ /
| | /| / / /_  / __/  |   / 
| |/ |/ / __/ / /___ /   |  
|__/|__/_/   /_____//_/|_|  
EOF
  printf "%b  WFEX%b  %s  %bDirect CLI mode%b
" "$BOLD" "$R" "Web Fuzzer and Enumerator" "$DG" "$R"
  printf "%b  Authorized security testing only.%b

" "$DG" "$R"
}

# ── Utility ───────────────────────────────────────────────────────
die() {
  echo -e "${RD}[!]${R} $*" >&2
  exit 1
}

warn() {
  $SILENT || echo -e "${YL}[!]${R} $*" >&2
}

info() {
  $SILENT || echo -e "${DG}[*]${R} $*"
}

ok() {
  $SILENT || echo -e "${GR}[+]${R} $*"
}

cleanup() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

is_positive_int() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( "$1" > 0 ))
}

is_nonnegative_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

sleep_delay() {
  # Converts milliseconds to seconds without bc.
  # Example: 250 -> 0.250 ; 1500 -> 1.500
  (( DELAY > 0 )) || return 0
  local seconds
  printf -v seconds "%d.%03d" "$((DELAY / 1000))" "$((DELAY % 1000))"
  sleep "$seconds"
}

urlencode_path() {
  # Basic path-safe normalization for spaces.
  # Keeps this Bash-only and dependency-light.
  local s="$1"
  s="${s// /%20}"
  printf "%s" "$s"
}

resolve_wordlist() {
  local input="$1"

  [[ -z "$input" ]] && return 1

  if [[ -f "$input" ]]; then
    printf "%s\n" "$input"
    return 0
  fi

  if [[ -d "$WL_DIR" ]]; then
    if [[ -f "${WL_DIR}/${input}" ]]; then
      printf "%s\n" "${WL_DIR}/${input}"
      return 0
    fi
    if [[ -f "${WL_DIR}/${input}.txt" ]]; then
      printf "%s\n" "${WL_DIR}/${input}.txt"
      return 0
    fi
  fi

  return 1
}

list_wordlists() {
  echo -e "${BOLD}Wordlist directory:${R} ${WL_DIR}"
  echo

  if [[ ! -d "$WL_DIR" ]]; then
    echo -e "${DG}No wordlists installed.${R}"
    echo
    echo "mkdir -p \"${WL_DIR}\""
    echo "cp your_wordlist.txt \"${WL_DIR}/\""
    echo
    echo "Common sources:"
    echo "  /usr/share/wordlists/dirb/common.txt"
    echo "  /usr/share/wordlists/dirb/big.txt"
    echo "  /usr/share/seclists/Discovery/Web-Content/common.txt"
    exit 0
  fi

  local count=0
  while IFS= read -r -d '' f; do
    local name lines
    name=$(basename "$f")
    lines=$(wc -l < "$f" 2>/dev/null || echo "?")
    printf " %-34s %s lines\n" "$name" "$lines"
    count=$((count + 1))
  done < <(find "$WL_DIR" -maxdepth 2 -type f \( -name "*.txt" -o -name "*.lst" \) -print0 | sort -z)

  [[ $count -eq 0 ]] && echo -e " ${DG}(no .txt or .lst files found)${R}"
  echo
  echo -e "${DG}Usage: -w common or -w /full/path/to/file.txt${R}"
  exit 0
}

install_wordlist() {
  local src="$1"
  local dst_name="${2:-$(basename "$src")}"

  [[ -f "$src" ]] || die "File not found: $src"

  mkdir -p "$WL_DIR"
  cp "$src" "${WL_DIR}/${dst_name}"

  local lines
  lines=$(wc -l < "${WL_DIR}/${dst_name}" 2>/dev/null || echo "?")
  ok "Installed: ${WL_DIR}/${dst_name} (${lines} lines)"
  exit 0
}

get_wordlist() {
  if [[ -n "$WORDLIST" && -f "$WORDLIST" ]]; then
    sed 's/\r$//' "$WORDLIST" | awk '
      NF && $0 !~ /^[[:space:]]*#/ {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
        if ($0 != "") print $0
      }
    '
  else
    printf '%s\n' "${BUILTIN_WORDLIST[@]}"
  fi
}

codes_to_regex() {
  local codes="$1"
  [[ "$codes" =~ ^[0-9,]+$ ]] || die "Invalid status code list: $codes"
  printf "^(%s)$" "$(echo "$codes" | tr ',' '|')"
}

get_ua() {
  local -a ua_array=()

  if [[ -n "$UA_FILE" && -f "$UA_FILE" ]]; then
    mapfile -t ua_array < <(sed 's/\r$//' "$UA_FILE" | awk 'NF && $0 !~ /^[[:space:]]*#/')
  else
    ua_array=("${BUILTIN_UAS[@]}")
  fi

  [[ ${#ua_array[@]} -gt 0 ]] || ua_array=("WFEX/1.0")
  printf "%s" "${ua_array[RANDOM % ${#ua_array[@]}]}"
}

detect_cloud() {
  local h="$1"
  local cloud="none" waf=""

  echo "$h" | grep -qiE "x-amz|cloudfront|awselb" && cloud="AWS"
  echo "$h" | grep -qiE "x-azure-ref|windows-azure" && cloud="Azure"
  echo "$h" | grep -qiE "x-cloud-trace|gws" && cloud="GCP"
  echo "$h" | grep -qiE "^cf-ray:|cloudflare" && waf="Cloudflare"
  echo "$h" | grep -qiE "akamai|x-akamai" && waf="Akamai"
  echo "$h" | grep -qiE "x-sucuri|sucuri" && waf="Sucuri"
  echo "$h" | grep -qiE "x-fastly|fastly" && waf="Fastly"

  [[ -n "$waf" ]] && printf "%s+WAF:%s" "$cloud" "$waf" || printf "%s" "$cloud"
}

detect_server() {
  echo "$1" | awk 'BEGIN{IGNORECASE=1} /^server:/ {sub(/^[^:]+:[[:space:]]*/, ""); gsub(/\r/, ""); print; exit}'
}

initial_probe() {
  local target="$1"
  curl -k -sI --max-time "$TIMEOUT" "$target" 2>/dev/null || true
}

initial_code_from_headers() {
  echo "$1" | awk 'NR==1 {print $2}'
}

normalize_url() {
  URL="${URL%/}"

  if [[ "$URL" != http://* && "$URL" != https://* ]]; then
    URL="https://${URL}"
  fi

  local headers code
  headers=$(initial_probe "$URL")
  code=$(initial_code_from_headers "$headers")

  if [[ -z "$code" || "$code" == "000" ]]; then
    if $FALLBACK_HTTP && [[ "$URL" == https://* ]]; then
      local http_url="${URL/https:\/\//http://}"
      local http_headers http_code
      http_headers=$(initial_probe "$http_url")
      http_code=$(initial_code_from_headers "$http_headers")

      if [[ -n "$http_code" && "$http_code" != "000" ]]; then
        warn "HTTPS did not respond; falling back to HTTP: $http_url"
        URL="$http_url"
        printf "%s" "$http_headers"
        return 0
      fi
    fi
  fi

  printf "%s" "$headers"
}


print_table_header() {
  $SILENT && return 0
  $SHOW_HEADER || return 0
  $CLEAN_OUTPUT || return 0

  printf "\n"
  printf "%-11s %-5s %-9s %-7s %s\n" "TYPE" "CODE" "SIZE" "RISK" "URL"
  printf "%-11s %-5s %-9s %-7s %s\n" "-----------" "-----" "---------" "------" "------------------------------------------------------------"
  SHOW_HEADER=false
}

clear_progress_line() {
  if ! $NO_PROGRESS && ! $SILENT; then
    printf "\r%*s\r" 90 "" >&2
  fi
}

record_result() {
  local kind="$1" url="$2" code="$3" size="$4" label="$5"

  printf "%s\t%s\t%s\t%s\t%s\n" "$kind" "$url" "$code" "$size" "$label" >> "$RESULT_FILE"

  if [[ -n "$OUTPUT" ]]; then
    printf "[%s] %s [%s] size:%s\n" "$label" "$url" "$code" "$size" >> "$OUTPUT"
  fi
}

print_result() {
  local kind="$1" url="$2" code="$3" size="$4" label="$5"

  if $SILENT; then
    printf "%s [%s] size:%s\n" "$url" "$code" "$size"
    return
  fi

  if ! $CLEAN_OUTPUT; then
    local raw_color="$GR"
    [[ "$code" == "403" ]] && raw_color="$YL"
    [[ "$code" == "500" ]] && raw_color="$RD"
    [[ "$code" == 3* ]] && raw_color="$BL"
    [[ "$label" == "SENSITIVE" ]] && raw_color="$RD"

    clear_progress_line
    printf "${BOLD}${raw_color}[%s]${R} %s ${DG}[%s size:%s]${R}\n" "$label" "$url" "$code" "$size"
    return
  fi

  local risk="INFO"
  local type_label="$label"

  [[ "$label" == "DIR" ]] && risk="INFO"
  [[ "$label" == "FILE" ]] && risk="LOW"
  [[ "$label" == "SENSITIVE" ]] && risk="HIGH"
  [[ "$code" == "403" && "$label" != "SENSITIVE" ]] && risk="MED"
  [[ "$code" == "500" ]] && risk="MED"
  [[ "$code" == 3* ]] && risk="INFO"

  local color="$GR"
  [[ "$risk" == "INFO" ]] && color="$CY"
  [[ "$risk" == "LOW" ]] && color="$BL"
  [[ "$risk" == "MED" ]] && color="$YL"
  [[ "$risk" == "HIGH" ]] && color="$RD"

  clear_progress_line
  print_table_header

  if $USE_COLOR; then
    printf "%b%-11s%b %-5s %-9s %b%-7s%b %s\n" \
      "$color" "$type_label" "$R" "$code" "$size" "$color" "$risk" "$R" "$url"
  else
    printf "%-11s %-5s %-9s %-7s %s\n" "$type_label" "$code" "$size" "$risk" "$url"
  fi
}

do_request() {
  local target="$1"
  local ua flags output code size

  ua=$(get_ua)
  flags=(-k -s -o /dev/null -w "%{http_code}|%{size_download}" --max-time "$TIMEOUT")
  $FOLLOW_REDIRECT && flags+=(-L)

  sleep_delay

  output=$(curl "${flags[@]}" -H "User-Agent: $ua" "$target" 2>/dev/null || printf "000|0")
  code="${output%%|*}"
  size="${output##*|}"

  [[ "$code" =~ ^[0-9]{3}$ ]] || code="000"
  [[ "$size" =~ ^[0-9]+$ ]] || size="0"

  printf "%s|%s" "$code" "$size"
}

is_interesting_ext() {
  local ext="$1" item
  IFS=',' read -ra items <<< "$INTERESTING"
  for item in "${items[@]}"; do
    [[ "$ext" == "$item" ]] && return 0
  done
  return 1
}

test_dir() {
  local word="$1"
  local safe_word target response code size

  safe_word=$(urlencode_path "$word")
  target="${URL}/${safe_word}/"

  response=$(do_request "$target")
  code="${response%%|*}"
  size="${response##*|}"

  echo "$code" | grep -qE "$CODES_REGEX" || return 0

  record_result "dir" "$target" "$code" "$size" "DIR"
  print_result "dir" "$target" "$code" "$size" "DIR"
}

test_file() {
  local word="$1" ext="$2"
  local safe_word target response code size label

  ext="${ext#.}"
  [[ -z "$ext" ]] && return 0

  safe_word=$(urlencode_path "$word")
  target="${URL}/${safe_word}.${ext}"

  response=$(do_request "$target")
  code="${response%%|*}"
  size="${response##*|}"

  echo "$code" | grep -qE "$CODES_REGEX" || return 0

  label="FILE"
  is_interesting_ext "$ext" && label="SENSITIVE"

  record_result "file" "$target" "$code" "$size" "$label"
  print_result "file" "$target" "$code" "$size" "$label"
}

wait_for_slot() {
  local max="$1"

  while (( $(jobs -pr | wc -l) >= max )); do
    if wait -n 2>/dev/null; then
      :
    else
      sleep 0.05
    fi
  done
}

run_parallel() {
  local word ext
  local total_words=0 current=0

  total_words=$(get_wordlist | wc -l | tr -d ' ')

  while IFS= read -r word; do
    [[ -z "$word" || "$word" == \#* ]] && continue
    current=$((current + 1))

    if ! $NO_PROGRESS && ! $SILENT; then
      printf "\r${DG}Scanning:${R} %s/%s | found:%s | sensitive:%s" "$current" "$total_words" "$(wc -l < "$RESULT_FILE" 2>/dev/null | tr -d ' ')" "$(awk -F '\t' '$5==\"SENSITIVE\"{c++} END{print c+0}' "$RESULT_FILE" 2>/dev/null)" >&2
    fi

    if ! $ONLY_FILES; then
      wait_for_slot "$THREADS"
      test_dir "$word" &
    fi

    if ! $ONLY_DIRS; then
      IFS=',' read -ra exts <<< "$EXTENSIONS"
      for ext in "${exts[@]}"; do
        ext="${ext//[[:space:]]/}"
        [[ -z "$ext" ]] && continue
        wait_for_slot "$THREADS"
        test_file "$word" "$ext" &
      done
    fi
  done < <(get_wordlist)

  wait || true

  if ! $NO_PROGRESS && ! $SILENT; then
    printf "\r%*s\r" 60 "" >&2
  fi
}

usage() {
  tool_banner
  cat << HELP
${BOLD}Usage:${R} $0 -u <url> [options]

${BOLD}WFEX - Web Fuzzer & Enumerator eXtended${R}

${BOLD}Options:${R}
  -u, --url              Target URL. If scheme is omitted, HTTPS is tried first.
  -w, --wordlist         Wordlist: name, path, or use --list-wordlists.
  -o, --output           Save results to file.
  -t, --threads          Parallel requests. Default: 20.
  -T, --timeout          Request timeout in seconds. Default: 8.
  -d, --delay            Delay between requests in milliseconds. Default: 0.
                          This version does not require bc.
  -e, --extensions       Extensions, comma-separated. Default: php,html,js,txt,bak,old,zip,json,xml,sql,env.
  -c, --codes            HTTP codes of interest. Default: 200,204,301,302,403,500.
  -a, --agents           Custom User-Agent file. Default: built-in list.

  --dirs-only            Test directories only.
  --files-only           Test files only.
  --follow               Follow redirects.
  --no-fallback          Do not fallback from HTTPS to HTTP.
  --silent               Results only.
  --no-color             Disable colors.
  --no-progress          Disable progress line.
  --raw                 Old verbose output style.
  --no-header           Do not print the table header.
  --list-wordlists       Show available wordlists.
  --install-wordlist     Install a wordlist: --install-wordlist /path/file.txt [name].
  -h, --help             Show this help.

${BOLD}Examples:${R}
  $0 -u http://target.local -w /usr/share/wordlists/dirb/big.txt
  $0 -u target.local -w common -t 50 -e php,asp,aspx --silent
  $0 -u http://target.local --dirs-only -c 200,301,403 -o results.txt
  $0 -u http://target.local -d 250 -t 10

HELP
  exit 0
}

# ── Argument parsing ──────────────────────────────────────────────
[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--url) URL="${2:-}"; shift 2 ;;
    -w|--wordlist) WORDLIST="${2:-}"; shift 2 ;;
    -o|--output) OUTPUT="${2:-}"; shift 2 ;;
    -t|--threads) THREADS="${2:-}"; shift 2 ;;
    -T|--timeout) TIMEOUT="${2:-}"; shift 2 ;;
    -d|--delay) DELAY="${2:-}"; shift 2 ;;
    -e|--extensions) EXTENSIONS="${2:-}"; shift 2 ;;
    -c|--codes) CODES="${2:-}"; shift 2 ;;
    -a|--agents) UA_FILE="${2:-}"; shift 2 ;;
    --dirs-only) ONLY_DIRS=true; shift ;;
    --files-only) ONLY_FILES=true; shift ;;
    --follow) FOLLOW_REDIRECT=true; shift ;;
    --no-fallback) FALLBACK_HTTP=false; shift ;;
    --silent) SILENT=true; shift ;;
    --no-color) USE_COLOR=false; shift ;;
    --no-progress) NO_PROGRESS=true; shift ;;
    --raw) CLEAN_OUTPUT=false; shift ;;
    --no-header) SHOW_HEADER=false; shift ;;
    --list-wordlists) list_wordlists ;;
    --install-wordlist)
      [[ -n "${2:-}" ]] || die "--install-wordlist requires a file path"
      install_wordlist "$2" "${3:-}"
      ;;
    -h|--help) usage ;;
    *) die "Unknown option: $1" ;;
  esac
done

# ── Validations ───────────────────────────────────────────────────
[[ -n "$URL" ]] || die "-u is required"
command -v curl >/dev/null 2>&1 || die "missing dependency: curl"

is_positive_int "$THREADS" || die "Invalid THREADS: $THREADS"
is_positive_int "$TIMEOUT" || die "Invalid TIMEOUT: $TIMEOUT"
is_nonnegative_int "$DELAY" || die "Invalid DELAY in ms: $DELAY"

if $ONLY_DIRS && $ONLY_FILES; then
  die "--dirs-only and --files-only cannot be used together"
fi

if [[ -n "$UA_FILE" && ! -f "$UA_FILE" ]]; then
  die "User-Agent file not found: $UA_FILE"
fi

if [[ -n "$WORDLIST" ]]; then
  if ! resolved=$(resolve_wordlist "$WORDLIST"); then
    die "Wordlist not found: \"${WORDLIST}\". Run --list-wordlists to see available options."
  fi
  WORDLIST="$resolved"
fi

CODES_REGEX=$(codes_to_regex "$CODES")

TMP_DIR=$(mktemp -d)
RESULT_FILE="${TMP_DIR}/results.tsv"
touch "$RESULT_FILE"

# ── Prepare output file ───────────────────────────────────────────
if [[ -n "$OUTPUT" ]]; then
  mkdir -p "$(dirname "$OUTPUT")" 2>/dev/null || true
  printf "# WFEX | %s | %s\n\n" "$URL" "$(date '+%Y-%m-%d %H:%M:%S')" > "$OUTPUT"
fi

# ── Initial request ───────────────────────────────────────────────
START_TIME=$(date +%s)
INIT_HEADERS=$(normalize_url)
CLOUD=$(detect_cloud "$INIT_HEADERS")
SERVER=$(detect_server "$INIT_HEADERS")
INIT_CODE=$(initial_code_from_headers "$INIT_HEADERS")
WL_SOURCE="${WORDLIST:-built-in}"
WL_COUNT=$(get_wordlist | wc -l | tr -d ' ')

if ! $SILENT; then
  tool_banner
  echo -e "${BOLD}${URL}${R} ${DG}[${INIT_CODE:-?}]${R} server:${SERVER:-?} cloud:${CLOUD}"
  echo -e "${DG}wfex${R} | wordlist:$(basename "$WL_SOURCE") words:${WL_COUNT} threads:${THREADS} delay:${DELAY}ms"
  echo
fi

# ── Run ───────────────────────────────────────────────────────────
run_parallel

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

FOUND_DIRS=$(awk -F '\t' '$1=="dir"{c++} END{print c+0}' "$RESULT_FILE")
FOUND_FILES=$(awk -F '\t' '$1=="file" && $5=="FILE"{c++} END{print c+0}' "$RESULT_FILE")
FOUND_INTERESTING=$(awk -F '\t' '$1=="file" && $5=="SENSITIVE"{c++} END{print c+0}' "$RESULT_FILE")

if ! $SILENT; then
  echo
  echo -e "${DG}dirs:${R} ${FOUND_DIRS} ${DG}files:${R} ${FOUND_FILES} ${DG}sensitive:${R} ${FOUND_INTERESTING} ${DG}time:${R} ${ELAPSED}s"
  [[ -n "$OUTPUT" ]] && echo -e "${DG}saved:${R} ${OUTPUT}"
fi

if [[ -n "$OUTPUT" ]]; then
  printf "\n# dirs: %s files: %s sensitive: %s time: %ss\n" \
    "$FOUND_DIRS" "$FOUND_FILES" "$FOUND_INTERESTING" "$ELAPSED" >> "$OUTPUT"
fi
