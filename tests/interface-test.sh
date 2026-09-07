#!/usr/bin/env bash
# End-to-end tests for the SignCollect interface, as both admin and user.
#
# Exercises the HTTP surface the browser actually calls - login, session,
# user management, labels, glosses, notes - and checks role separation:
# every admin-only action is repeated as a normal user and must be refused.
#
# Self-contained: creates its own fixtures and removes them at the end, so it
# is safe to re-run. Never point it at production - it writes.
#
# Usage: BASE=https://dev2.taila8bdbd.ts.net tests/interface-test.sh
set -uo pipefail

BASE=${BASE:-https://dev2.taila8bdbd.ts.net}
ADMIN_USER=${ADMIN_USER:-gomer}
ADMIN_PASS=${ADMIN_PASS:-123}
TS=$(date +%s)
TESTUSER="itest_$TS"
TESTPASS="itestpw_$TS"
TESTLABEL="itest-label-$TS"
TESTGLOS="ITEST_GLOS_$TS"

pass=0; fail=0; skip=0
declare -a FAILURES

case "$BASE" in *signcollect.nl*) echo "refusing to run against production"; exit 2 ;; esac

# --- helpers ------------------------------------------------------------
# req/form print the body on stdout and leave the HTTP code in $STATUS.
#
# $STATUS goes through a file, not a variable: these are almost always called
# as body=$(req ...), which runs them in a subshell, and a variable set there
# never reaches the caller. Assigning STATUS directly meant every assertion
# read the *previous* request's code.
STATUSFILE=$(mktemp)
trap 'rm -f "$STATUSFILE"' EXIT
_status() { STATUS=$(cat "$STATUSFILE" 2>/dev/null); }

req() {
  local m=$1 p=$2 ck=$3 body=${4:-}
  local out
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
# is <label> <expected...> - passes if $STATUS is any of the expected codes
is() {
  local label=$1; shift
  _status
  for c in "$@"; do [ "$STATUS" = "$c" ] && { ok "$label ($STATUS)"; return; }; done
  bad "$label (got $STATUS, want ${*})"
}
# Build the session cookie the way login.html does: straight from the login
# response, signature included. Hand-assembling one stopped working when the
# cookie became signed - which is the point.
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

section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# --- 1. authentication --------------------------------------------------
section "authentication"
ALOGIN=$(login "$ADMIN_USER" "$ADMIN_PASS")
r=$ALOGIN
case "$r" in *'"status":"success"'*) ok "admin login accepted" ;; *) bad "admin login: $r" ;; esac
case "$r" in *'"sig":"'*) ok "login returns a session signature" ;; *) note "login returns no signature (host not migrated)" ;; esac
ADMIN_ID=$(printf '%s' "$ALOGIN" | sed -nE 's/.*"userId":"?([0-9]+)"?.*/\1/p')
[ -n "$ADMIN_ID" ] && ok "admin userId returned ($ADMIN_ID)" || bad "no userId in login response"

r=$(form /login_sc.php "" "username=$ADMIN_USER&password=definitely-wrong")
case "$r" in *'"status":"failure"'*) ok "wrong password refused" ;; *) bad "wrong password not refused: $r" ;; esac

r=$(form /login_sc.php "" "username=no_such_user_$TS&password=x")
case "$r" in *'"status":"failure"'*) ok "unknown user refused" ;; *) bad "unknown user not refused: $r" ;; esac

ACOOK=$(printf '%s' "$ALOGIN" | cookie_from_login) || bad "could not build admin session cookie"

# --- 2. unauthenticated access must be refused --------------------------
section "unauthenticated access"
for p in /menu_beta/php_api/current_user.php /menu_beta/php_api/glosses_list.php \
         /menu_beta/php_api/filters_options.php; do
  req GET "$p" "" >/dev/null; is "refused without session: $p" 401 403
done

# --- 3. session as admin ------------------------------------------------
section "session (admin)"
req GET /menu_beta/php_api/session.php "$ACOOK" >/dev/null;      is "session.php" 200
body=$(req GET /menu_beta/php_api/current_user.php "$ACOOK");    is "current_user.php" 200
case "$body" in *'"role":"admin"'*) ok "role reported as admin" ;; *) bad "role not admin: $(printf '%s' "$body" | head -c 80)" ;; esac
req GET /menu_beta/php_api/datasets.php "$ACOOK" >/dev/null;     is "datasets.php" 200
req GET /menu_beta/php_api/filters_options.php "$ACOOK" >/dev/null; is "filters_options.php" 200

# --- 4. user management (admin) -----------------------------------------
section "user management (admin)"
body=$(form /menu_beta/users_api.php "$ACOOK" "action=list&requestingUserId=$ADMIN_ID"); is "list users" 200
case "$body" in *"$ADMIN_USER"*) ok "admin appears in user list" ;; *) bad "admin missing from list" ;; esac

body=$(form /menu_beta/users_api.php "$ACOOK" \
       "action=add&requestingUserId=$ADMIN_ID&user=$TESTUSER&pass=$TESTPASS&role=user")
is "add user" 200
case "$body" in *'"error"'*) bad "add user returned error: $(printf '%s' "$body" | head -c 120)" ;; *) ok "add user reported no error" ;; esac

body=$(form /menu_beta/users_api.php "$ACOOK" "action=list&requestingUserId=$ADMIN_ID")
case "$body" in *"$TESTUSER"*) ok "new user appears in list" ;; *) bad "new user absent from list" ;; esac

r=$(login "$TESTUSER" "$TESTPASS")
case "$r" in *'"status":"success"'*) ok "new user can log in" ;; *) bad "new user cannot log in: $r" ;; esac
USER_ID=$(printf '%s' "$r" | sed -nE 's/.*"userId":"?([0-9]+)"?.*/\1/p')
UCOOK=$(printf '%s' "$r" | cookie_from_login)

# --- 5. labels ----------------------------------------------------------
section "labels"
body=$(req POST /menu_beta/php_api/labels_create.php "$ACOOK" \
       "{\"label\":\"$TESTLABEL\",\"color\":\"#3366ff\"}")
is "create label (admin)" 200
LABEL_ID=$(printf '%s' "$body" | sed -nE 's/.*"id":"?([0-9]+)"?.*/\1/p')
[ -n "$LABEL_ID" ] && ok "label id returned ($LABEL_ID)" || bad "no label id: $(printf '%s' "$body" | head -c 120)"

body=$(req GET /menu_beta/php_api/filters_options.php "$ACOOK")
case "$body" in *"$TESTLABEL"*) ok "new label offered in filters_options" ;;
  *) bad "new label NOT in filters_options - it will not appear on a gloss form" ;; esac

# --- 6. glosses ---------------------------------------------------------
section "glosses"
req POST /menu_beta/php_api/glosses_create.php "$ACOOK" '{}' >/dev/null
is "create gloss with empty body refused" 400

body=$(req POST /menu_beta/php_api/glosses_create.php "$ACOOK" \
       "{\"glos\":\"$TESTGLOS\",\"glos_engels\":\"itest\",\"labels\":[\"$TESTLABEL\"]}")
is "create gloss (admin)" 200 201
GLOS_ID=$(printf '%s' "$body" | sed -nE 's/.*"id":"?([0-9]+)"?.*/\1/p')
[ -n "$GLOS_ID" ] && ok "gloss id returned ($GLOS_ID)" || bad "no gloss id: $(printf '%s' "$body" | head -c 160)"

body=$(req GET /menu_beta/php_api/glosses_list.php "$ACOOK"); is "list glosses" 200
case "$body" in *"$TESTGLOS"*) ok "new gloss appears in list" ;; *) bad "new gloss absent from list" ;; esac

if [ -n "${GLOS_ID:-}" ]; then
  req GET "/menu_beta/php_api/logbook_get.php?id=$GLOS_ID" "$ACOOK" >/dev/null; is "logbook_get for gloss" 200
  req GET "/menu_beta/php_api/notes_list.php?id=$GLOS_ID" "$ACOOK" >/dev/null;  is "notes_list for gloss" 200
  req GET "/menu_beta/php_api/phonology_get.php?id=$GLOS_ID" "$ACOOK" >/dev/null; is "phonology_get for gloss" 200
else
  note "gloss-scoped endpoints skipped - no gloss id"
fi

# --- 7. role separation: the same actions as a normal user --------------
section "role separation (non-admin)"
if [ -z "${USER_ID:-}" ]; then
  note "skipped - test user was not created"
else
  req GET /menu_beta/php_api/current_user.php "$UCOOK" >/dev/null; is "user can read own session" 200
  # Honest attempt: the user supplies their own id.
  body=$(form /menu_beta/users_api.php "$UCOOK" "action=list&requestingUserId=$USER_ID")
  case "$body" in *Unauthorized*) ok "non-admin refused user list" ;;
    *) bad "NON-ADMIN CAN LIST USERS: $(printf '%s' "$body" | head -c 80)" ;; esac
  body=$(form /menu_beta/users_api.php "$UCOOK" "action=add&requestingUserId=$USER_ID&user=esc_$TS&pass=x&role=admin")
  case "$body" in *Unauthorized*) ok "non-admin refused add user" ;;
    *) bad "NON-ADMIN CAN CREATE USERS: $(printf '%s' "$body" | head -c 80)" ;; esac

  # Escalation 1: borrow an admin id via the POST field requireAdmin used to trust.
  body=$(form /menu_beta/users_api.php "$UCOOK" "action=list&requestingUserId=$ADMIN_ID")
  case "$body" in *Unauthorized*) ok "non-admin cannot borrow an admin id" ;;
    *) bad "ESCALATION: non-admin listed users via requestingUserId=$ADMIN_ID" ;; esac

  # Escalation 2: edit role in one's own cookie. The signature covers identity,
  # and role is read from the database, so this must fail on both counts.
  ESC=$(printf '%s' "$UCOOK" | sed 's/"role":"user"/"role":"admin"/')
  body=$(form /menu_beta/users_api.php "$ESC" "action=list")
  case "$body" in *Unauthorized*) ok "editing role in the cookie does not grant admin" ;;
    *) bad "ESCALATION: cookie-edited role granted admin" ;; esac
fi

# --- 8. session forgery -------------------------------------------------
section "session integrity"
FORGED=$(cookie_for "nonexistent_user_$TS" 999999 admin)
body=$(req GET /menu_beta/php_api/current_user.php "$FORGED"); _status
case "$STATUS" in
  200) bad "FORGED session accepted - sessionObject is unsigned client-side JSON" ;;
  *)   ok "forged session refused ($STATUS)" ;;
esac

# --- 9. static pages the menu links to ----------------------------------
section "menu targets"
for p in / /menu_beta/index.html /menu_old/menu.html /videoFix/index.html \
         /studioIndex/ /zin/zinnen.html /nmm/fastView.html /hh/index.html \
         /downloadVideos/downloadThemaVideo.html /menu_beta/labels_add.html \
         /menu_beta/batch_add.html /themas.html /menu_beta/users.html \
         /stats.html /login.html /logout.html; do
  req GET "$p" "$ACOOK" >/dev/null; is "$p" 200
done

# --- 10. secrets stay denied -------------------------------------------
section "secrets"
for p in /mysql_config.php /.env /zin/.env /menu_beta/signbank_sync/config.php; do
  req GET "$p" "$ACOOK" >/dev/null; is "denied: $p" 403 404
done

# --- cleanup ------------------------------------------------------------
section "cleanup"
if [ -n "${GLOS_ID:-}" ]; then
  req POST /menu_beta/php_api/glosses_delete.php "$ACOOK" "{\"id\":$GLOS_ID}" >/dev/null
  is "remove test gloss" 200 204
fi
if [ -n "${USER_ID:-}" ]; then
  form /menu_beta/users_api.php "$ACOOK" "action=delete&requestingUserId=$ADMIN_ID&userId=$USER_ID" >/dev/null
  is "remove test user" 200
fi
note "test label $TESTLABEL left in place - no delete endpoint exists"

# --- summary ------------------------------------------------------------
printf '\n\033[1m%s\033[0m\n' "$BASE"
printf 'passed %d   failed %d   notes %d\n' "$pass" "$fail" "$skip"
if [ "$fail" -gt 0 ]; then
  printf '\nfailures:\n'; printf '  - %s\n' "${FAILURES[@]}"
fi
exit $(( fail > 0 ))
