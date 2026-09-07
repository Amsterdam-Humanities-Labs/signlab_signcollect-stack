#!/usr/bin/env bash
# End-to-end tests for the Signbank connector: the admin page, its API, and
# the gloss dump it rebuilds.
#
# What it asserts, in the order it matters:
#
#   - the page and every action are admin-only, checked as an anonymous
#     caller, as a normal user, and with a forged cookie;
#   - the stored API key is never served, never echoed back, and never
#     readable through apache;
#   - a refresh actually reaches signbank.cls.ru.nl, and the JSON it produces
#     parses and has the shape the four consumers expect;
#   - the published dump is still valid afterwards.
#
# The refresh it runs is the bounded one - a few dozen glosses written to a
# staging file, never published. That exercises the whole pipeline
# (enumeration, auth, transform, atomic write) in about half a minute, and
# cannot replace 7.4k live entries with a sample if it goes wrong. FULL=1
# additionally runs the real thing, which takes minutes and makes ~7.5k
# requests against a third party, so it is opt-in.
#
# Creates one throwaway user for the role-separation checks and deletes it.
# Never point it at production - it writes.
#
# Usage: BASE=https://dev2.taila8bdbd.ts.net tests/signbank-test.sh
#        FULL=1 BASE=... tests/signbank-test.sh
set -uo pipefail

BASE=${BASE:-https://dev2.taila8bdbd.ts.net}
ADMIN_USER=${ADMIN_USER:-gomer}
ADMIN_PASS=${ADMIN_PASS:-123}
FULL=${FULL:-0}
FULL_TIMEOUT=${FULL_TIMEOUT:-900}
TS=$(date +%s)
TESTUSER="sbtest_$TS"
TESTPASS="sbtestpw_$TS"

API=/menu_beta/php_api/signbank_admin.php
PAGE=/menu_beta/signbank.php

pass=0; fail=0; skip=0
declare -a FAILURES

case "$BASE" in *signcollect.nl*) echo "refusing to run against production"; exit 2 ;; esac

# --- helpers ------------------------------------------------------------
# Same shape as interface-test.sh: the body goes to stdout and the HTTP code
# through a file, because these are called as body=$(req ...) - a subshell,
# where a plain variable assignment would never reach the caller.
STATUSFILE=$(mktemp)
trap 'rm -f "$STATUSFILE"' EXIT
_status() { STATUS=$(cat "$STATUSFILE" 2>/dev/null); }

# req <method> <path> <cookie> [json body] [timeout seconds]
req() {
  local m=$1 p=$2 ck=$3 body=${4:-} tmo=${5:-30} out
  if [ -n "$body" ]; then
    out=$(curl -sS -X "$m" -b "$ck" -H 'Content-Type: application/json' \
          -d "$body" -w $'\n%{http_code}' "$BASE$p" --max-time "$tmo" 2>/dev/null)
  else
    out=$(curl -sS -X "$m" -b "$ck" -w $'\n%{http_code}' "$BASE$p" --max-time "$tmo" 2>/dev/null)
  fi
  printf '%s' "${out##*$'\n'}" > "$STATUSFILE"
  printf '%s' "${out%$'\n'*}"
}
form() {
  local p=$1 ck=$2 body=$3 out
  out=$(curl -sS -X POST -b "$ck" -d "$body" -w $'\n%{http_code}' "$BASE$p" --max-time 30 2>/dev/null)
  printf '%s' "${out##*$'\n'}" > "$STATUSFILE"
  printf '%s' "${out%$'\n'*}"
}
ok()   { pass=$((pass+1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
bad()  { fail=$((fail+1)); FAILURES+=("$1"); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
note() { skip=$((skip+1)); printf '  --   %s\n' "$1"; }
is() {
  local label=$1; shift
  _status
  for c in "$@"; do [ "$STATUS" = "$c" ] && { ok "$label ($STATUS)"; return; }; done
  bad "$label (got $STATUS, want ${*})"
}
has() { # has <label> <body> <needle>
  case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 - not in: $(printf '%s' "$2" | head -c 140)" ;; esac
}
hasnt() {
  case "$2" in *"$3"*) bad "$1 - FOUND '$3' in: $(printf '%s' "$2" | head -c 140)" ;; *) ok "$1" ;; esac
}
# Sessions are HMAC-signed, so the cookie has to come from a real login.
cookie_from_login() {
  python3 -c '
import json,sys
d=json.loads(sys.stdin.read())
if d.get("status")!="success": sys.exit(1)
print("sessionObject="+json.dumps({k:d.get(k,"") for k in
      ("userId","username","role","expiresAt","sig")},separators=(",",":")))'
}
login() { form /login_sc.php "" "username=$1&password=$2"; }
jget()  { python3 -c 'import json,sys
d=json.loads(sys.stdin.read())
for k in sys.argv[1].split("."):
    d = d.get(k) if isinstance(d,dict) else None
    if d is None: print(""); raise SystemExit
print(d)' "$1"; }

section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# --- 1. sessions --------------------------------------------------------
section "sessions"
ALOGIN=$(login "$ADMIN_USER" "$ADMIN_PASS")
case "$ALOGIN" in *'"status":"success"'*) ok "admin login accepted" ;;
  *) bad "admin login: $ALOGIN"; echo "cannot continue without an admin session"; exit 1 ;; esac
ACOOK=$(printf '%s' "$ALOGIN" | cookie_from_login)
ADMIN_ID=$(printf '%s' "$ALOGIN" | sed -nE 's/.*"userId":"?([0-9]+)"?.*/\1/p')

body=$(form /menu_beta/users_api.php "$ACOOK" \
       "action=add&requestingUserId=$ADMIN_ID&user=$TESTUSER&pass=$TESTPASS&role=user")
case "$body" in *'"error"'*) bad "create non-admin fixture: $body" ;; *) ok "created non-admin fixture" ;; esac
ULOGIN=$(login "$TESTUSER" "$TESTPASS")
UCOOK=$(printf '%s' "$ULOGIN" | cookie_from_login)
USER_ID=$(printf '%s' "$ULOGIN" | sed -nE 's/.*"userId":"?([0-9]+)"?.*/\1/p')
[ -n "${USER_ID:-}" ] && ok "non-admin can log in ($USER_ID)" || bad "non-admin could not log in"

# --- 2. the page is admin-only ------------------------------------------
# Unlike users.html, the connector page is PHP and gated server-side: it
# shows the state of a credential, so a non-admin must not receive the
# markup at all, not merely be redirected by a script inside it.
section "page access"
req GET "$PAGE" "$ACOOK" >/dev/null;  is "admin gets the page" 200
req GET "$PAGE" "" >/dev/null;        is "anonymous is sent to login" 302
if [ -n "${UCOOK:-}" ]; then
  body=$(req GET "$PAGE" "$UCOOK");   is "non-admin refused the page" 403
  hasnt "refusal page carries no markup from the real page" "$body" "signbank_admin.php"
else
  note "non-admin page check skipped - no fixture user"
fi

# --- 3. the API is admin-only -------------------------------------------
section "api access"
req GET "$API" "" >/dev/null;                                  is "status without a session" 401
req POST "$API" "" '{"action":"test"}' >/dev/null;             is "test without a session" 401
req POST "$API" "" '{"action":"save_key","key":"x-forged-key-123"}' >/dev/null
is "save_key without a session" 401
req POST "$API" "" '{"action":"refresh","mode":"full"}' >/dev/null
is "refresh without a session" 401

if [ -n "${UCOOK:-}" ]; then
  req GET "$API" "$UCOOK" >/dev/null;                          is "non-admin status" 403
  req POST "$API" "$UCOOK" '{"action":"save_key","key":"x-forged-key-123"}' >/dev/null
  is "NON-ADMIN CANNOT REPLACE THE API KEY" 403
  req POST "$API" "$UCOOK" '{"action":"refresh","mode":"full"}' >/dev/null
  is "non-admin cannot start a refresh" 403
  req POST "$API" "$UCOOK" '{"action":"schedule","schedule":"hourly"}' >/dev/null
  is "non-admin cannot change the schedule" 403

  # Role comes from the users table, so editing it in one's own cookie
  # changes nothing. Same escalation interface-test.sh checks on users_api.
  ESC=$(printf '%s' "$UCOOK" | sed 's/"role":"user"/"role":"admin"/')
  req GET "$API" "$ESC" >/dev/null;                            is "cookie-edited role is not admin" 403
else
  note "non-admin API checks skipped - no fixture user"
fi

FORGED='sessionObject={"username":"nobody","userId":"999999","role":"admin"}'
req GET "$API" "$FORGED" >/dev/null;                           is "forged session refused" 401

# --- 4. status ----------------------------------------------------------
section "status"
STATUS_BODY=$(req GET "$API" "$ACOOK"); is "status as admin" 200
has  "status reports the Signbank host"    "$STATUS_BODY" '"base_url":"https://signbank.cls.ru.nl"'
has  "status reports the dataset"          "$STATUS_BODY" '"dataset":"NGT"'
has  "status reports the dump path"        "$STATUS_BODY" '"path":"/web/signbank_data/glosses_transformed.json"'
has  "status reports the dump exists"      "$STATUS_BODY" '"exists":true'
has  "status reports the dump is writable" "$STATUS_BODY" '"writable":true'

KEY_SET=$(printf '%s' "$STATUS_BODY" | jget key.set)
if [ "$KEY_SET" = "True" ]; then
  ok "an API key is configured"
else
  bad "no API key configured - the connector cannot reach Signbank"
fi

ENTRIES=$(printf '%s' "$STATUS_BODY" | jget dump.entries)
if [ -n "$ENTRIES" ] && [ "$ENTRIES" -gt 1000 ] 2>/dev/null; then
  ok "status counts the published glosses ($ENTRIES)"
else
  bad "status reports a nonsense gloss count: '$ENTRIES'"
fi

# --- 5. the key is never handed back ------------------------------------
# The page shows enough to tell two keys apart and no more. If the key ever
# appears in a response or is served by apache, that is the leak this whole
# storage arrangement exists to prevent.
section "key handling"
KEYFILE=$(printf '%s' "$STATUS_BODY" | jget key.file)
[ -n "$KEYFILE" ] && ok "status names the key file ($KEYFILE)" || bad "status does not name the key file"
has "status shows only the last four characters" "$STATUS_BODY" '"hint":"...'

# Read the key straight off the host if we can, and prove it is not in any
# response. Without host access the weaker check below still runs.
HOSTKEY=""
if [ -n "${SIGNBANK_HOST:-}" ]; then
  HOSTKEY=$(ssh "$SIGNBANK_HOST" "sudo cat ${KEYFILE:-/web/signbank_data/.signbank_key} 2>/dev/null" | tr -d '\r\n')
fi
if [ -n "$HOSTKEY" ]; then
  hasnt "the key itself is not in the status response" "$STATUS_BODY" "$HOSTKEY"
else
  note "key value not compared - set SIGNBANK_HOST=user@host to check it directly"
fi

# The state directory has to live inside the docroot - the dump is served
# from it - so everything in it that is not the dump is a dotfile, which
# apache denies. A 200 on any of these is the connector leaking its own
# internals to anyone who asks.
for p in "/signbank_data/.signbank_key" "/signbank_data/.settings.json" \
         "/signbank_data/.refresh_state.json" "/menu_beta/signbank_sync/config.php"; do
  req GET "$p" "$ACOOK" >/dev/null
  is "denied: $p" 403 404
done

req POST "$API" "$ACOOK" '{"action":"save_key","key":""}' >/dev/null
is "empty key refused" 400
req POST "$API" "$ACOOK" '{"action":"save_key","key":"short"}' >/dev/null
is "malformed key refused" 400

# --- 6. reaching Signbank -----------------------------------------------
section "signbank connection"
body=$(req POST "$API" "$ACOOK" '{"action":"test"}' 60)
is "connection test" 200
has "connection test succeeded"          "$body" '"ok":true'
has "connection test got a gloss back"   "$body" '"status":200'

# --- 7. a real refresh --------------------------------------------------
# The bounded refresh: enumerate the dataset, fetch a sample, transform it,
# write it atomically to a staging file. Everything the full refresh does
# except replacing the live dump.
section "refresh"
body=$(req POST "$API" "$ACOOK" '{"action":"refresh","mode":"sample","limit":25}' 300)
is "sample refresh" 200
has "sample refresh reports success"     "$body" '"ok":true'
has "sample refresh staged, not published" "$body" '"staging":true'

SAMPLE_N=$(printf '%s' "$body" | jget entries)
SAMPLE_MS=$(printf '%s' "$body" | jget duration_ms)
AVAILABLE=$(printf '%s' "$body" | jget available)
if [ "${SAMPLE_N:-0}" = "25" ]; then
  ok "sample refresh fetched 25 glosses in ${SAMPLE_MS} ms"
else
  bad "sample refresh fetched '$SAMPLE_N' glosses, wanted 25"
fi
if [ -n "$AVAILABLE" ] && [ "$AVAILABLE" -gt 1000 ] 2>/dev/null; then
  ok "enumeration saw the whole dataset ($AVAILABLE glosses)"
else
  bad "enumeration saw '$AVAILABLE' glosses - the dataset listing failed"
fi

# --- 8. the dump the consumers read -------------------------------------
# Shape, not just parseability: a list of single-key objects keyed by
# Signbank gloss id, each carrying the fields signbank_ecv.php reads. Any
# other shape silently breaks the Glos Wizard, zin, hh and nmm.
section "dump shape"
# The dump is served from the connector's directory. The docroot-root URL it
# used to have is gone on purpose: a redirect or a symlink there would keep a
# consumer nobody repointed working, and hide that it was missed.
req GET /signbank_data/glosses_transformed.json "$ACOOK" >/dev/null
is "the dump is served" 200
req GET /glosses_transformed.json "$ACOOK" >/dev/null
is "the old docroot-root URL is gone" 404

if curl -sS --max-time 120 -o /tmp/sbtest-dump.$$ "$BASE/signbank_data/glosses_transformed.json" 2>/dev/null; then
  shape=$(python3 - /tmp/sbtest-dump.$$ <<'PY'
import json,sys
try:
    d = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as e:
    print("PARSE_FAIL", e); raise SystemExit
if not isinstance(d, list) or not d:
    print("NOT_A_LIST"); raise SystemExit
bad = 0
for e in d:
    if not isinstance(e, dict) or len(e) != 1: bad += 1; continue
    (k, v), = e.items()
    if not k.isdigit() or not isinstance(v, dict): bad += 1
first = d[0]
(gid, fields), = first.items()
required = ["Annotation ID Gloss: Dutch", "In The Web Dictionary"]
missing = [r for r in required if r not in fields]
withsenses = sum(1 for e in d for v in e.values() if "Senses: Dutch" in v)
print("OK", len(d), bad, ",".join(missing) or "-", withsenses)
PY
)
  case "$shape" in
    OK*)
      set -- $shape
      total=$2; malformed=$3; missing=$4; senses=$5
      ok "the dump parses as JSON ($total entries)"
      [ "$malformed" = "0" ] && ok "every entry is one gloss id mapping to a field map" \
                             || bad "$malformed entries are not {\"<id>\": {...}}"
      [ "$missing" = "-" ]   && ok "entries carry the fields the consumers read" \
                             || bad "first entry is missing: $missing"
      if [ "$senses" -gt 0 ] 2>/dev/null; then ok "$senses entries carry senses"
      else bad "no entry carries 'Senses: Dutch' - the wizard would find nothing"; fi
      ;;
    *) bad "the published dump does not parse: $shape" ;;
  esac
  rm -f /tmp/sbtest-dump.$$
else
  bad "could not download the dump"
fi

# --- 9. schedule --------------------------------------------------------
section "schedule"
body=$(req POST "$API" "$ACOOK" '{"action":"schedule","schedule":"daily","daily_time":"04:15"}')
is "set a daily schedule" 200
has "schedule saved" "$body" '"daily_time":"04:15"'
body=$(req GET "$API" "$ACOOK")
has "schedule survives a reload" "$body" '"schedule":"daily"'

req POST "$API" "$ACOOK" '{"action":"schedule","schedule":"weekly"}' >/dev/null
is "an unknown interval is refused" 400
req POST "$API" "$ACOOK" '{"action":"schedule","schedule":"daily","daily_time":"25:99"}' >/dev/null
is "a nonsense time is refused" 400

body=$(req POST "$API" "$ACOOK" '{"action":"schedule","schedule":"off","daily_time":"03:30"}')
is "schedule turned off again" 200

req POST "$API" "$ACOOK" '{"action":"nonsense"}' >/dev/null
is "unknown action refused" 400

# --- 10. the full refresh, on request -----------------------------------
section "full refresh"
if [ "$FULL" != "1" ]; then
  note "skipped - FULL=1 runs it (minutes, ~7.5k requests to signbank.cls.ru.nl)"
else
  before=$(req GET "$API" "$ACOOK" | jget dump.entries)
  body=$(req POST "$API" "$ACOOK" '{"action":"refresh","mode":"full"}' 60)
  is "full refresh started" 200
  has "refresh reports it started" "$body" '"started":true'

  waited=0
  while [ "$waited" -lt "$FULL_TIMEOUT" ]; do
    st=$(req GET "$API" "$ACOOK")
    case "$(printf '%s' "$st" | jget state.status)" in
      running) sleep 15; waited=$((waited+15)) ;;
      *) break ;;
    esac
  done
  status=$(printf '%s' "$st" | jget state.status)
  if [ "$status" = "idle" ]; then
    n=$(printf '%s' "$st" | jget dump.entries)
    ms=$(printf '%s' "$st" | jget state.last_result.duration_ms)
    ok "full refresh finished: $n glosses in $((ms/1000))s (was $before)"
    [ "${n:-0}" -gt 1000 ] 2>/dev/null && ok "the published dump grew to a plausible size" \
                                       || bad "the published dump holds $n glosses"
  else
    bad "full refresh ended as '$status' after ${waited}s"
  fi
fi

# --- cleanup ------------------------------------------------------------
section "cleanup"
if [ -n "${USER_ID:-}" ]; then
  form /menu_beta/users_api.php "$ACOOK" \
       "action=delete&requestingUserId=$ADMIN_ID&userId=$USER_ID" >/dev/null
  is "remove fixture user" 200
fi

printf '\n\033[1m%s\033[0m\n' "$BASE"
printf 'passed %d   failed %d   notes %d\n' "$pass" "$fail" "$skip"
if [ "$fail" -gt 0 ]; then
  printf '\nfailures:\n'; printf '  - %s\n' "${FAILURES[@]}"
fi
exit $(( fail > 0 ))
