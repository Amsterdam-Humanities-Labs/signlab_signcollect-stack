#!/usr/bin/env bash
# End-to-end tests for signcollect-lib - the shared database configuration at
# /web/lib - and for its first two consumers, signlab_hh and
# signlab_studio_beta.
#
# What it asserts, in the order it matters:
#
#   - the library is deployed and none of it is servable. It is a directory
#     of includes, so every path under /lib must be 403, and so must the env
#     file it reads;
#   - the endpoints that used to 500 return real rows. hh/getGlosses.php and
#     studio_beta/zin/getSenses.php both opened by including a gitignored
#     credential file that no fresh checkout has and nothing provisioned, so
#     they failed before reading a byte of the request;
#   - both repos reach the *same* database. hh gets its settings as
#     $db_config[...] through hh/db_config.php, studio_beta gets the four bare
#     globals through db.php and the compat shim. The same gloss looked up
#     through each accessor must come back with the same id - that is the
#     single-source claim, tested rather than asserted;
#   - the ~170 call sites this migration deliberately did not touch still
#     work, through /web/mysql_config.php;
#   - authentication still runs in front of the config, not behind it. An
#     endpoint that 401s for an anonymous caller must not start 500ing or,
#     worse, start answering, because its credential loading moved.
#
# Read-only: it looks things up and never writes a row, so it needs no
# fixtures and no cleanup. Never point it at production anyway.
#
# Usage: BASE=https://dev2.taila8bdbd.ts.net tests/lib-test.sh
set -uo pipefail

BASE=${BASE:-https://dev2.taila8bdbd.ts.net}
ADMIN_USER=${ADMIN_USER:-gomer}
ADMIN_PASS=${ADMIN_PASS:-123}

pass=0; fail=0; skip=0
declare -a FAILURES

case "$BASE" in *signcollect.nl*) echo "refusing to run against production"; exit 2 ;; esac

# --- helpers ------------------------------------------------------------
# Same shape as interface-test.sh and signbank-test.sh: the body goes to
# stdout and the HTTP code through a file, because these are called as
# body=$(req ...) - a subshell, where a plain assignment to STATUS would
# never reach the caller.
STATUSFILE=$(mktemp)
trap 'rm -f "$STATUSFILE"' EXIT
_status() { STATUS=$(cat "$STATUSFILE" 2>/dev/null); }

# req <method> <path> <cookie> [json body]
req() {
  local m=$1 p=$2 ck=$3 body=${4:-} out
  if [ -n "$body" ]; then
    out=$(curl -sS -X "$m" -b "$ck" -H 'Content-Type: application/json' \
          -d "$body" -w $'\n%{http_code}' "$BASE$p" --max-time 20 2>/dev/null)
  else
    out=$(curl -sS -X "$m" -b "$ck" -w $'\n%{http_code}' "$BASE$p" --max-time 20 2>/dev/null)
  fi
  printf '%s' "${out##*$'\n'}" > "$STATUSFILE"
  printf '%s' "${out%$'\n'*}"
}
form() {
  local p=$1 ck=$2 body=$3 out
  out=$(curl -sS -X POST -b "$ck" -d "$body" -w $'\n%{http_code}' "$BASE$p" --max-time 20 2>/dev/null)
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
# Sessions are HMAC-signed, so the cookie has to come from a real login -
# a hand-assembled one is refused, which the forgery check below relies on.
cookie_from_login() {
  python3 -c '
import json,sys
d=json.loads(sys.stdin.read())
if d.get("status")!="success": sys.exit(1)
print("sessionObject="+json.dumps({k:d.get(k,"") for k in
      ("userId","username","role","expiresAt","sig")},separators=(",",":")))'
}
# An unsigned cookie, for the forgery test only.
cookie_for() { printf 'sessionObject={"username":"%s","userId":"%s","role":"%s"}' "$1" "$2" "$3"; }
login() { form /login_sc.php "" "username=$1&password=$2"; }
# First numeric glosID in a JSON body, whatever the surrounding shape.
glosid_for() { printf '%s' "$1" | python3 -c '
import json,re,sys
raw=sys.stdin.read()
def walk(o):
    if isinstance(o,dict):
        if str(o.get("glos","")).upper()==GLOS and "glosID" in o: return o["glosID"]
        for v in o.values():
            r=walk(v)
            if r is not None: return r
    elif isinstance(o,list):
        for v in o:
            r=walk(v)
            if r is not None: return r
    return None
GLOS=sys.argv[1] if len(sys.argv)>1 else "BOEK"
try: print(walk(json.loads(raw)) or "")
except Exception: print("")' "${2:-BOEK}"; }

section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# --- 1. a real session ---------------------------------------------------
section "authentication"
ALOGIN=$(login "$ADMIN_USER" "$ADMIN_PASS")
case "$ALOGIN" in *'"status":"success"'*) ok "admin login accepted" ;;
                  *) bad "admin login: $ALOGIN" ;; esac
ACOOK=$(printf '%s' "$ALOGIN" | cookie_from_login) || bad "could not build admin session cookie"
[ -n "${ACOOK:-}" ] && ok "session cookie built from the login response" \
                    || bad "no session cookie - the rest of this run is meaningless"
FORGED=$(cookie_for "$ADMIN_USER" 38 admin)

# --- 2. the library is deployed, and none of it is servable --------------
# /web/lib is a directory of includes. Every path under it being 403 is not
# defence in depth for one sensitive file - it is that the whole directory
# has no business answering an HTTP request at all.
section "library is installed and not servable"
for p in /lib/db_config.php /lib/compat/mysql_config.php /lib/compat/db_credentials.php \
         /lib/.env.example /lib/README.md /lib/; do
  req GET "$p" "" >/dev/null; is "denied: $p" 403
done
# The credentials themselves. /web/.env is the one place they exist.
for p in /.env /lib/.env /hh/.env /studio_beta/.env; do
  req GET "$p" "" >/dev/null; is "denied: $p" 403 404
done
# The two per-repo bootstraps are includes too: fetching one must never
# produce output, whatever apache decides to do about the request.
for p in /hh/db_config.php /studio_beta/db.php; do
  body=$(req GET "$p" "$ACOOK")
  _status
  case "$STATUS" in 403|404) ok "not served: $p ($STATUS)" ;;
    200) [ -z "$body" ] && ok "served but emits nothing: $p" \
                        || bad "$p emitted a body: $(printf '%s' "$body" | head -c 120)" ;;
    *) bad "$p returned $STATUS" ;;
  esac
done

# --- 3. the endpoints that used to 500 -----------------------------------
# Both of these included a gitignored per-repo credential file. Neither host
# had one, so both failed at include time - a 500 with an empty body, before
# any of their own code ran.
section "endpoints that had no credential file at all"
GLOSSES=$(req GET "/hh/getGlosses.php?action=search&term=boek" "$ACOOK")
is "hh/getGlosses.php answers" 200
has "hh/getGlosses.php returns a result set" "$GLOSSES" '"results"'
has "hh/getGlosses.php found the BOEK gloss"  "$GLOSSES" '"glos":"BOEK"'
hasnt "hh/getGlosses.php is not a config error" "$GLOSSES" 'Configuration error'
hasnt "hh/getGlosses.php did not fail to connect" "$GLOSSES" 'Connection failed'

# studio_beta's own copy of getSenses.php is gone (it called /zin/ anyway);
# its db.php path is still exercised through lookups.php below. The gloss
# comparison uses zin's endpoint, which reaches the database through zin's
# own accessor - still a second repository reading through the library.
SENSES=$(req GET "/zin/getSenses.php?sense=boek" "$ACOOK")
is "zin/getSenses.php answers" 200
has "zin/getSenses.php found the BOEK gloss" "$SENSES" '"glos":"BOEK"'
hasnt "zin/getSenses.php is not a config error" "$SENSES" 'Configuration error'
hasnt "zin/getSenses.php did not fail to connect" "$SENSES" 'Connection failed'

# --- 4. one source of truth ---------------------------------------------
# hh reads $db_config['host'|'user'|'password'|'database'] through
# hh/db_config.php; zin reads its own mysql_config through the compat shim. Different repositories,
# different accessors, and until now different credentials. The same gloss
# coming back with the same id through both is the whole point of the
# library, so it is checked rather than assumed.
section "both repos reach the same database"
HH_ID=$(glosid_for "$GLOSSES" BOEK)
ZIN_ID=$(glosid_for "$SENSES" BOEK)
if [ -n "$HH_ID" ] && [ -n "$ZIN_ID" ]; then
  [ "$HH_ID" = "$ZIN_ID" ] && ok "BOEK is glosID $HH_ID through both accessors" \
                           || bad "BOEK is $HH_ID in hh but $ZIN_ID in zin - two databases"
else
  bad "could not read a glosID from both endpoints (hh='$HH_ID' zin='$ZIN_ID')"
fi

# --- 5. the rest of each repo's consumers --------------------------------
# hh's other three call sites went through the same missing file; every one
# of studio_beta's seventeen went through the same missing include in db.php.
# A sample of each, because "the two endpoints in the ticket work" is not the
# claim being made.
section "the other consumers of the same two config paths"
r=$(req GET "/hh/api.php?action=dashboard" "$ACOOK");  is "hh/api.php" 200
has "hh/api.php returns dashboard counts" "$r" 'hh_index'
r=$(req GET "/hh/get_begrippen.php" "$ACOOK");         is "hh/get_begrippen.php" 200
has "hh/get_begrippen.php returns a page of rows" "$r" '"total"'
# GET is not a method it accepts; 405 still means it loaded its config first.
req GET "/hh/save_subtitle.php" "$ACOOK" >/dev/null;   is "hh/save_subtitle.php past config" 200 405

for p in "/studio_beta/lookups.php?what=labels" "/studio_beta/lookups.php?what=thema" \
         /studio_beta/fetch_glosses.php "/studio_beta/lookups.php?what=nmm_themas" \
         "/studio_beta/lookups.php?what=users"; do
  r=$(req GET "$p" "$ACOOK")
  is "studio_beta consumer: $p" 200
  hasnt "no config error from $p" "$r" 'Configuration error'
done

# --- 6. what this migration deliberately left alone ----------------------
# Roughly 170 call sites across the estate include some spelling of
# mysql_config.php. Two consumers were migrated, on purpose, and the rest
# must keep working exactly as they did - including five inside hh itself.
section "unmigrated call sites still work"
for p in "/hh/getZinnen.php" "/hh/getMT.php"; do
  r=$(req GET "$p" "$ACOOK")
  is "still working through ../mysql_config.php: $p" 200
  hasnt "no config error from $p" "$r" 'Configuration error'
done
req GET /mysql_config.php "" >/dev/null; is "the docroot shim is still denied over http" 403

# --- 7. authentication still runs before the config ----------------------
# Moving where an endpoint gets its credentials must not move where it checks
# who is asking. Every one of these authenticates first, so an anonymous
# caller must get 401 - not 500 (config ran first and blew up) and certainly
# not 200.
section "auth still precedes config"
for p in "/hh/getGlosses.php?action=search&term=boek" /hh/api.php /hh/get_begrippen.php \
         /hh/save_subtitle.php /hh/getZinnen.php; do
  req GET "$p" "" >/dev/null; is "refused without a session: $p" 401
done
# hh does not verify the cookie signature. By design, and stated at the top
# of hh/auth.php: it re-checks the (userId, username) pair against the users
# table instead, so a forged cookie naming a real account is accepted there
# even though the portal would reject it. That is a pre-existing gap, not
# something this migration introduced, and closing it belongs to whoever owns
# hh's auth - but it is worth one line of output rather than silence.
req GET "/hh/getGlosses.php?action=search&term=boek" "$FORGED" >/dev/null
_status
[ "$STATUS" = 200 ] \
  && note "hh accepts an unsigned cookie naming a real user (see hh/auth.php) - $STATUS" \
  || ok "hh refuses an unsigned cookie ($STATUS)"

# What hh does check is that the account exists and is not blocked, and that
# lookup is itself a database query - through ../mysql_config.php, the path
# this migration left alone. A cookie naming nobody must be refused, and a
# 401 here is evidence the lookup ran rather than that it errored.
GHOST=$(cookie_for "no_such_user_$$" 999999 admin)
for p in "/hh/getGlosses.php?action=search&term=boek" /hh/api.php /hh/get_begrippen.php; do
  req GET "$p" "$GHOST" >/dev/null; is "cookie naming an unknown user refused: $p" 401
done

# The portal's own endpoints do verify the signature, and must keep doing so.
for p in /menu_beta/php_api/current_user.php /menu_beta/php_api/glosses_list.php; do
  req GET "$p" "$FORGED" >/dev/null; is "forged cookie refused by the portal: $p" 401 403
done

printf '\n\033[1m%s\033[0m\n' "$BASE"
printf 'passed %d   failed %d   notes %d\n' "$pass" "$fail" "$skip"
if [ "$fail" -gt 0 ]; then
  printf '\nfailures:\n'; printf '  - %s\n' "${FAILURES[@]}"
fi
exit $(( fail > 0 ))
