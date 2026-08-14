#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WFEX="${ROOT}/wfex.sh"
TMP="$(mktemp -d)"
trap '[[ -f "$TMP/pid" ]] && kill "$(cat "$TMP/pid")" 2>/dev/null || true; rm -rf "$TMP"' EXIT
fail(){ echo "FAIL: $*" >&2; exit 1; }
ok(){ echo "PASS: $*"; }

bash -n "$WFEX" || fail "shell syntax"
ok "shell syntax"
"$WFEX" version | grep -q "WFEX 3.2.9" || fail "version command"
ok "version command"
"$WFEX" help | grep -q '<url> <extension|extensions>' || fail "simple command syntax"
"$WFEX" help | grep -q -- '--progress' || fail "progress option"
"$WFEX" help | grep -q -- '--summary' || fail "summary option"
"$WFEX" help | grep -q -- '--redirects' || fail "redirect option"
ok "help and simple command syntax"
"$WFEX" check >/dev/null 2>&1 || fail "environment check"
ok "environment check"

cat > "$TMP/server.py" <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        routes={
            '/admin/':(200,b'admin',None), '/uploads/':(200,b'uploads',None), '/css/':(200,b'css',None),
            '/prog/':(200,b'prog',None), '/login.php':(200,b'login',None), '/home.php':(200,b'home',None),
            '/robots.txt':(200,b'robots',None), '/redirect/':(302,b'','/admin/'), '/secret.env':(200,b'secret',None),
        }
        if self.path in routes:
            code,data,loc=routes[self.path]
            self.send_response(code); self.send_header('Server','Apache/2.4.7'); self.send_header('X-Powered-By','PHP/5.5.9')
            if loc: self.send_header('Location',loc)
            self.send_header('Content-Length',str(len(data))); self.end_headers(); self.wfile.write(data)
        else:
            data=b'not found'; self.send_response(404); self.send_header('Content-Length',str(len(data))); self.end_headers(); self.wfile.write(data)
    def log_message(self,*a): pass
HTTPServer(('127.0.0.1',8791),H).serve_forever()
PY
python3 "$TMP/server.py" >/dev/null 2>&1 & echo $! > "$TMP/pid"
sleep 1
printf 'admin\nuploads\ncss\nprog\nlogin\nhome\nrobots.txt\nredirect\nsecret\nmissing\n' > "$TMP/words.txt"
OUT="$TMP/out"; ERR="$TMP/err"
"$WFEX" http://127.0.0.1:8791 "$TMP/words.txt" php --redirects --no-color >"$OUT" 2>"$ERR" || fail "clean scan"
cat "$OUT" "$ERR" >/dev/null
# Combined stream should contain the visual sections, but no default progress/summary/table noise.
cat "$OUT" "$ERR" | grep -q 'WFEX  |  Web Fuzzer & Enumerator eXtended' || fail "WFEX identity"
cat "$OUT" "$ERR" | grep -q 'Target        ' || fail "configuration block"
cat "$OUT" "$ERR" | grep -qF '|-----------------------------------------------------------------------|' || fail "separator format"
python3 - "$OUT" "$ERR" <<'PY2' || fail "lateral pipes should be removed"
import sys
for path in sys.argv[1:]:
    text=open(path, encoding='utf-8', errors='ignore').read().splitlines()
    for line in text:
        if line.startswith('|') and line != '|-----------------------------------------------------------------------|':
            raise SystemExit(1)
PY2
! grep -q 'Directories Found' "$OUT" "$ERR" 2>/dev/null || fail "duplicate directories title"
! grep -q 'Files Found' "$OUT" "$ERR" 2>/dev/null || fail "duplicate files title"
cat "$OUT" "$ERR" | grep -q 'Directory Found:' || fail "directory format"
cat "$OUT" "$ERR" | grep -q 'File Found:' || fail "file format"
! grep -q 'Redirect Found' "$OUT" "$ERR" 2>/dev/null || fail "redirect should use File Found style"
! grep -q 'Scanning' "$OUT" "$ERR" 2>/dev/null || fail "progress should be hidden by default"
! grep -q 'Summary' "$OUT" "$ERR" 2>/dev/null || fail "summary should be hidden by default"
! grep -q 'Results' "$OUT" "$ERR" 2>/dev/null || fail "final table should be hidden by default"
! grep -q 'missing/' "$OUT" "$ERR" 2>/dev/null || fail "404 should be hidden"
ok "clean grouped live scan"

OUT2="$TMP/out2"; ERR2="$TMP/err2"
"$WFEX" http://127.0.0.1:8791 "$TMP/words.txt" env --redirects --no-color --progress --summary >"$OUT2" 2>"$ERR2" || fail "optional progress/summary scan"
cat "$OUT2" "$ERR2" | grep -q 'Scanning' || fail "progress opt-in"
cat "$OUT2" "$ERR2" | grep -q 'Summary' || fail "summary opt-in"
ok "optional progress and summary"

OUT3="$TMP/out3"; ERR3="$TMP/err3"
"$WFEX" http://127.0.0.1:8791 "$TMP/words.txt" env --threads 4 --no-live --no-color >"$OUT3" 2>"$ERR3" || fail "extension scan"
grep -q "Results" "$OUT3" "$ERR3" || fail "final table in no-live mode"
grep -q "secret.env" "$OUT3" "$ERR3" || fail "extension discovery"
grep -q "SENSITIVE" "$OUT3" "$ERR3" || fail "sensitive classification"
ok "final table mode"

if "$WFEX" http://127.0.0.1:8791 "$TMP/words.txt" --threads 0 >/dev/null 2>&1; then fail "invalid threads accepted"; fi
ok "invalid input rejected"

echo "All WFEX tests passed."
