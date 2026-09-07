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
         /menu_beta/php_api/filters_options.php \
         "/menu_beta/php_api/wizard_search.php?q=BOEK" \
         "/menu_beta/php_api/wizard_suggest.php?glos=BOEK" \
         /menu_beta/php_api/activity_log.php; do
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

# --- 6b. glos wizard ----------------------------------------------------
# The wizard asks one question - does this sign already exist? - of the local
# gloss table and of the Signbank ECV dump at once. Both halves are checked
# here, but only the local half can be asserted unconditionally: a host that
# has not had the export installed has no dump to search. The endpoint says
# so in `ecv`, and this follows suit rather than reporting a green run for a
# search that only ever saw half the data.
section "glos wizard"
req GET /signbank_data/glosses_transformed.json "$ACOOK" >/dev/null
is "signbank ECV dump is served" 200

req GET /menu_beta/php_api/wizard_search.php "$ACOOK" >/dev/null
is "wizard search without a query refused" 400
req GET /menu_beta/php_api/wizard_suggest.php "$ACOOK" >/dev/null
is "wizard suggest without a gloss refused" 400

body=$(req GET "/menu_beta/php_api/wizard_search.php?q=$TESTGLOS" "$ACOOK")
is "wizard search" 200
case "$body" in *"\"$TESTGLOS\""*) ok "wizard search finds the local test gloss" ;;
  *) bad "wizard search missed $TESTGLOS: $(printf '%s' "$body" | head -c 120)" ;; esac

case "$body" in
  *'"ecv":true'*)
    ok "signbank ECV dump is loaded"
    body=$(req GET "/menu_beta/php_api/wizard_search.php?q=BOEK" "$ACOOK")
    case "$body" in *'"source":"signbank"'*) ok "wizard search returns signbank hits" ;;
      *) bad "wizard search found nothing in the ECV for BOEK" ;; esac
    case "$body" in *'"phonology"'*) ok "signbank hits carry their phonology" ;;
      *) bad "signbank hit has no phonology block - adopting one would create an empty row" ;; esac
    ;;
  *) note "signbank ECV dump absent - signbank half of the wizard not exercised" ;;
esac

# Naming: TESTGLOS was created above, so the wizard must refuse to reuse the
# name and offer the first free suffix instead.
body=$(req GET "/menu_beta/php_api/wizard_suggest.php?glos=$TESTGLOS" "$ACOOK")
is "wizard suggest for an existing gloss" 200
case "$body" in *'"exists":true'*) ok "wizard suggest sees the existing gloss" ;;
  *) bad "wizard suggest did not see $TESTGLOS: $(printf '%s' "$body" | head -c 120)" ;; esac
case "$body" in *"\"glos\":\"$TESTGLOS-A\""*) ok "wizard suggest offers $TESTGLOS-A" ;;
  *) bad "wizard suggest offered the wrong name: $(printf '%s' "$body" | head -c 120)" ;; esac

body=$(req GET "/menu_beta/php_api/wizard_suggest.php?glos=itest%20free%20$TS" "$ACOOK")
case "$body" in *'"exists":false'*) ok "wizard suggest reports an unused name as free" ;;
  *) bad "wizard suggest called an unused name taken: $(printf '%s' "$body" | head -c 120)" ;; esac
case "$body" in *"\"glos\":\"ITEST-FREE-$TS\""*) ok "wizard suggest normalises to an uppercase hyphenated gloss" ;;
  *) bad "wizard suggest did not normalise: $(printf '%s' "$body" | head -c 120)" ;; esac

# Adopting a Signbank gloss goes through the ordinary create path, carrying
# the Signbank id and phonology with it. Assert the phonology actually lands -
# a row created without it is the failure mode worth catching.
body=$(req POST /menu_beta/php_api/glosses_create.php "$ACOOK" \
       "{\"glos\":\"${TESTGLOS}_SB\",\"glos_engels\":\"itest\",\"signbank\":\"2850\",\"phonology\":{\"Handeness\":\"2s\",\"virtualObjectt\":\"itest\"},\"fonologie_fase1\":1,\"fonologie_fase2\":1}")
is "adopt a signbank gloss" 200 201
SB_GLOS_ID=$(printf '%s' "$body" | sed -nE 's/.*"id":"?([0-9]+)"?.*/\1/p')
if [ -n "${SB_GLOS_ID:-}" ]; then
  body=$(req GET "/menu_beta/php_api/phonology_get.php?id=$SB_GLOS_ID" "$ACOOK")
  case "$body" in *'"Handeness":"2s"'*) ok "adopted gloss keeps its signbank phonology" ;;
    *) bad "adopted gloss lost its phonology: $(printf '%s' "$body" | head -c 120)" ;; esac
  case "$body" in *'"fonologie_fase1":"1"'*) ok "adopted gloss is marked fonologie fase 1 done" ;;
    *) bad "adopted gloss not marked fase 1 done" ;; esac
else
  note "adopted-gloss checks skipped - no gloss id"
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

# --- 7b. user activity (admin-only) -------------------------------------
# activity_log is a record of which member of staff opened which page and
# when, so the endpoint is admin-only and the refusals matter as much as the
# data. Paging is exercised for real: two pages of one row each must not be
# the same row, which is the failure an OFFSET bug produces.
section "user activity"
body=$(req GET /menu_beta/php_api/activity_log.php "$ACOOK")
is "activity log (admin)" 200
case "$body" in *'"rows"'*) ok "activity log returns an event list" ;;
  *) bad "no rows in activity log: $(printf '%s' "$body" | head -c 120)" ;; esac
case "$body" in *'"users"'*) ok "activity log returns the per-user aggregate" ;;
  *) bad "no per-user aggregate: $(printf '%s' "$body" | head -c 120)" ;; esac
case "$body" in *'"window"'*'"from"'*) ok "activity log reports its date window" ;;
  *) bad "no date window in response" ;; esac
# The admin has just made a dozen requests through this suite, and every page
# load in the interface POSTs users_api.php action=activity, so the admin must
# appear in the window with a non-zero count.
case "$body" in *"\"user\":\"$ADMIN_USER\""*) ok "admin appears in the per-user aggregate" ;;
  *) bad "admin missing from the per-user aggregate" ;; esac

# Log a page view as the admin, then assert it comes back at the top of the
# newest-first list. This is the round trip the page exists to show.
MARKPAGE="itest_activity_$TS.html"
form /menu_beta/users_api.php "$ACOOK" "action=activity&page=$MARKPAGE" >/dev/null
is "record a page visit" 200
body=$(req GET "/menu_beta/php_api/activity_log.php?pageSize=5" "$ACOOK")
case "$body" in *"$MARKPAGE"*) ok "the new visit appears at the top of the log" ;;
  *) bad "new visit not in the newest-first page: $(printf '%s' "$body" | head -c 200)" ;; esac

# Pagination. Two single-row pages must be two different rows - which needs
# two rows to exist. On a host with a history of test runs there always are;
# on one installed twenty minutes ago activity_log held exactly ONE row, the
# visit logged four lines above, so page 2 was empty and this failed on the
# only kind of host it matters on. The suite logs the second row itself rather
# than inheriting it from whatever happened to the host before.
form /menu_beta/users_api.php "$ACOOK" "action=activity&page=itest_activity2_$TS.html" >/dev/null
p1=$(req GET "/menu_beta/php_api/activity_log.php?pageSize=1&page=1" "$ACOOK")
is "activity log page 1" 200
p2=$(req GET "/menu_beta/php_api/activity_log.php?pageSize=1&page=2" "$ACOOK")
is "activity log page 2" 200
id1=$(printf '%s' "$p1" | sed -nE 's/.*"rows":\[\{"id":([0-9]+).*/\1/p')
id2=$(printf '%s' "$p2" | sed -nE 's/.*"rows":\[\{"id":([0-9]+).*/\1/p')
if [ -n "$id1" ] && [ -n "$id2" ] && [ "$id1" != "$id2" ]; then
  ok "pagination returns different rows (page1 id=$id1, page2 id=$id2)"
else
  bad "pagination returned the same row twice (id1=$id1 id2=$id2)"
fi
case "$p1" in *'"pageSize":1'*) ok "pageSize is honoured" ;;
  *) bad "pageSize not honoured: $(printf '%s' "$p1" | head -c 120)" ;; esac

# Filters. A user filter must return only that user's rows; a window that
# ended yesterday must exclude today's.
body=$(req GET "/menu_beta/php_api/activity_log.php?userId=$ADMIN_ID&pageSize=200" "$ACOOK")
is "activity log filtered by user" 200
OTHERS=$(printf '%s' "$body" | python3 -c '
import json,sys
d=json.load(sys.stdin)
me=sys.argv[1]
print(sum(1 for r in d["rows"] if str(r["userId"]) != me))' "$ADMIN_ID" 2>/dev/null)
case "$OTHERS" in 0) ok "user filter returns only that user's rows" ;;
  *) bad "user filter leaked $OTHERS rows from other users" ;; esac

YDAY=$(date -u -d '-1 day' +%Y-%m-%d 2>/dev/null || date -u -v-1d +%Y-%m-%d)
body=$(req GET "/menu_beta/php_api/activity_log.php?from=1970-01-01&to=$YDAY" "$ACOOK")
is "activity log with a closed date window" 200
case "$body" in *"\"to\":\"$YDAY\""*) ok "the requested window is echoed back" ;;
  *) bad "window not honoured: $(printf '%s' "$body" | head -c 160)" ;; esac
# Check the event list only. `users[].last_page` is a column of the `users`
# table, not of the log, so it rightly keeps showing today's page whatever
# window is asked for - matching on the whole body reads that as a leak.
LATE=$(printf '%s' "$body" | python3 -c '
import json,sys
d=json.load(sys.stdin)
cut=d["window"]["to"]
print(sum(1 for r in d["rows"] if str(r["visited_at"])[:10] > cut))' 2>/dev/null)
case "$LATE" in 0) ok "a window ending yesterday excludes today's visits" ;;
  *) bad "a window ending yesterday returned $LATE rows from after it" ;; esac

# Refusals. A non-admin must not read colleagues' activity, however well
# formed their own session is.
if [ -n "${USER_ID:-}" ]; then
  req GET /menu_beta/php_api/activity_log.php "$UCOOK" >/dev/null
  is "non-admin refused the activity log" 403
  req GET "/menu_beta/php_api/activity_log.php?userId=$USER_ID" "$UCOOK" >/dev/null
  is "non-admin refused even their own activity" 403
  ESC=$(printf '%s' "$UCOOK" | sed 's/"role":"user"/"role":"admin"/')
  req GET /menu_beta/php_api/activity_log.php "$ESC" >/dev/null
  is "cookie-edited role does not open the activity log" 403 401
else
  note "activity-log role checks skipped - test user was not created"
fi
req GET /menu_beta/php_api/activity_log.php "" >/dev/null
is "unauthenticated refused the activity log" 401

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
for p in / /menu_beta/index.html /videoFix/index.html \
         /studioIndex/ /zin/zinnen.html /nmm/fastView.html /hh/index.html \
         /downloadVideos/downloadThemaVideo.html /menu_beta/labels_add.html \
         /menu_beta/batch_add.html /themas.html /menu_beta/users.html \
         /menu_beta/activity.html /login.html /logout.html; do
  req GET "$p" "$ACOOK" >/dev/null; is "$p" 200
done
# The menu entry labelled "Gebruikersactiviteit" used to point at /stats.html,
# a static download-stats report that had nothing to do with user activity.
# It is deleted, not merely unlinked, so assert it is really gone - a leftover
# copy on the host would still be reachable to anyone who knows the URL.
req GET /stats.html "$ACOOK" >/dev/null; is "/stats.html is gone" 404

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
if [ -n "${SB_GLOS_ID:-}" ]; then
  req POST /menu_beta/php_api/glosses_delete.php "$ACOOK" "{\"id\":$SB_GLOS_ID}" >/dev/null
  is "remove adopted test gloss" 200 204
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
