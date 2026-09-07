#!/usr/bin/env bash
# Tests for the two things a demo host needs that no rsync can supply: a
# Composer autoloader for animMIDI, and pythonCron installed as a service.
#
# What it asserts:
#
#   - every entry point under animMIDI/public/ answers. All nine required
#     vendor/autoload.php on their first line, so all nine were a 500 until
#     deploy.sh started generating one; and behind that sat a second, hidden
#     failure, the gitignored mysql_config.php, which only an authenticated
#     request reaches. Both are checked, anonymous and as an admin, because
#     fixing only the first looks identical from the outside.
#
#   - pythonCron lives where it was put: code in /opt, host config in
#     /etc/opt, mutable state in /var/opt, and nothing at all under
#     /home/gomer, which is what it hardcoded upstream and what the user
#     asked it out of.
#
#   - the scheduler is registered with systemd, is running, and has the
#     Signbank ECV refresh in its database as a job it has actually executed.
#
#   - it is running the demo's job list and not production's. pythonCron's
#     own config.json schedules seventeen production jobs, three of whose
#     paths exist on a demo host; /opt/pythonCron/config.json is a symlink to
#     /etc/opt/pythonCron/config.json so that even a hand-run in that
#     directory cannot pick them up.
#
#   - and that the job is a no-op until an admin asks for it. The connector
#     page's schedule setting is what decides, so the test drives it: off
#     means "not due" and Signbank is never contacted; hourly means due. It
#     stops the scheduler around that window and restores the setting, so
#     turning the schedule on for one assertion cannot let a tick start a
#     7,500-request rebuild against a third party.
#
# Needs ssh to the host as well as HTTP: most of this is not observable from
# outside, and the parts that are were the parts that already worked.
#
# Usage: HOST=gomer@dev2 BASE=https://dev2.taila8bdbd.ts.net tests/pythoncron-test.sh
set -uo pipefail

BASE=${BASE:-https://dev2.taila8bdbd.ts.net}
HOST=${HOST:-demovps}
ADMIN_USER=${ADMIN_USER:-gomer}
ADMIN_PASS=${ADMIN_PASS:-123}
WEBROOT=${WEBROOT:-/web}

PC_HOME=/opt/pythonCron
PC_CONF=/etc/opt/pythonCron
PC_STATE=/var/opt/pythonCron
UNIT=python-scheduler.service
API=/menu_beta/php_api/signbank_admin.php

pass=0; fail=0
declare -a FAILURES

case "$BASE" in *signcollect.nl*) echo "refusing to run against production"; exit 2 ;; esac

ok()  { pass=$((pass+1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
bad() { fail=$((fail+1)); FAILURES+=("$1"); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# code <path> [cookie] - HTTP status of a GET
code() {
  if [ -n "${2:-}" ]; then
    curl -sS -o /dev/null -w '%{http_code}' -H "Cookie: $2" --max-time 30 "$BASE$1" 2>/dev/null
  else
    curl -sS -o /dev/null -w '%{http_code}' --max-time 30 "$BASE$1" 2>/dev/null
  fi
}
# is <label> <path> <cookie> <expected...>
is() {
  local label=$1 path=$2 ck=$3; shift 3
  local got; got=$(code "$path" "$ck")
  for c in "$@"; do [ "$got" = "$c" ] && { ok "$label ($got)"; return; }; done
  bad "$label (got $got, want ${*})"
}
# on <label> <remote command> - passes if the command exits 0
on() {
  local label=$1; shift
  if ssh "$HOST" "$*" >/dev/null 2>&1; then ok "$label"; else bad "$label"; fi
}
# says <label> <expected substring> <remote command>
says() {
  local label=$1 want=$2; shift 2
  local got; got=$(ssh "$HOST" "$*" 2>/dev/null)
  case "$got" in *"$want"*) ok "$label" ;; *) bad "$label (got '${got:0:120}')" ;; esac
}

# --- session ------------------------------------------------------------
# Built from the login response rather than hand-assembled: the cookie is
# signed, and only the server can produce the signature.
COOK=$(curl -sS -X POST -d "username=$ADMIN_USER&password=$ADMIN_PASS" \
       "$BASE/login_sc.php" 2>/dev/null | python3 -c '
import json,sys
d=json.loads(sys.stdin.read())
if d.get("status")!="success": sys.exit(1)
print("sessionObject="+json.dumps({k:d.get(k,"") for k in
      ("userId","username","role","expiresAt","sig")},separators=(",",":")))') \
  || { echo "cannot log in as $ADMIN_USER - nothing else here will work"; exit 2; }

# ========================================================================
section "animMIDI: the autoloader exists"
on "vendor/autoload.php generated on the host" "test -s $WEBROOT/animMIDI/vendor/autoload.php"
on "composer wrote a real classmap, not an empty stub" \
   "grep -q ComposerAutoloaderInit $WEBROOT/animMIDI/vendor/autoload.php"
on "the PSR-4 map points App\\\\ at app/" \
   "grep -q \"'App\\\\\\\\\\\\\\\\'\" $WEBROOT/animMIDI/vendor/composer/autoload_psr4.php"
# The second bug, which the first one hid: app/config/Database.php requires
# ../../mysql_config.php, gitignored upstream exactly as it is in mocapStudio.
on "mysql_config.php linked to the one credential file" \
   "test -L $WEBROOT/animMIDI/mysql_config.php &&
    test \"\$(readlink $WEBROOT/animMIDI/mysql_config.php)\" = $WEBROOT/mysql_config.php"

section "animMIDI: no entry point 500s"
# Anonymous: a redirect to login is the correct answer for the pages and 401
# for the POST-only endpoints. What matters is that none of them is a 500.
for p in delegate index stats upload download download-eaf; do
  is "anon $p.php redirects to login" "/animMIDI/public/$p.php" "" 302
done
for p in mark-processed review-status update-comment; do
  is "anon $p.php refuses" "/animMIDI/public/$p.php" "" 401 405
done
# Authenticated admin: the pages must actually render, which is the assertion
# that catches a database layer that cannot find its credentials.
for p in delegate index stats; do
  is "admin $p.php renders" "/animMIDI/public/$p.php" "$COOK" 200
done
body=$(curl -sS -H "Cookie: $COOK" --max-time 30 "$BASE/animMIDI/public/index.php" 2>/dev/null)
case "$body" in *"Motion Capture File Manager"*) ok "index.php returns the real page" ;;
  *) bad "index.php body is not the file manager page" ;; esac
case "$body" in *"Connection failed"*|*"Fatal error"*|*"vendor/autoload"*)
    bad "index.php body carries a PHP error" ;;
  *) ok "index.php body carries no PHP error" ;; esac

# ========================================================================
section "pythonCron: where it lives"
on "code in $PC_HOME"               "test -f $PC_HOME/scheduler_v2.py"
# Root-owned, and so is what is in it: rsync -a would have carried the
# workstation's uid across, which on this host coincidentally lands on the
# deploy user and elsewhere lands on nobody.
on "$PC_HOME is root-owned"         "test \"\$(stat -c %U $PC_HOME)\" = root"
on "and so is the code inside it"   "test \"\$(stat -c %U $PC_HOME/scheduler_v2.py)\" = root"
on "the service user cannot rewrite its own code" "! test -w $PC_HOME/scheduler_v2.py"
on "host config in $PC_CONF"        "test -f $PC_CONF/config.json"
on "mutable state in $PC_STATE"     "test -f $PC_STATE/scheduler_state.db"
on "$PC_STATE writable by the service user" "test -w $PC_STATE"
# The whole point of the exercise.
on "nothing under /home/\$USER"     "! test -e \"\$HOME/pythonCron\""
# It is a service, not a page. A repos.tsv row would have published it.
is "not served over HTTP" /pythonCron/ "" 404
is "scheduler_v2.py not served"  /pythonCron/scheduler_v2.py "" 404

section "pythonCron: registered with systemd"
says "$UNIT is enabled" enabled "systemctl is-enabled $UNIT"
says "$UNIT is running" active  "systemctl is-active $UNIT"
says "the unit runs the copy in $PC_HOME" "$PC_HOME/scheduler_v2.py" \
     "systemctl show -p ExecStart --value $UNIT"
says "state is directed out of the code directory" "PYTHONCRON_STATE_DIR=$PC_STATE" \
     "systemctl show -p Environment --value $UNIT"
# Asserted against the unit file rather than `systemctl show`, which reports
# ProtectSystem=no and an empty ReadWritePaths here. That is not the unit: it
# is /run/systemd/system/service.d/zzz-lxc-service.conf, a drop-in the
# container runtime installs that disables sandboxing for every service on
# the host - apache2's own PrivateTmp=true is neutered the same way. The
# fragment is what this deploy controls and what a real VPS would honour.
says "the unit sandboxes the filesystem" "ProtectSystem=full" \
     "grep '^ProtectSystem=' \$(systemctl show -p FragmentPath --value $UNIT)"
says "and names both writable paths" "$PC_STATE $WEBROOT" \
     "grep '^ReadWritePaths=' \$(systemctl show -p FragmentPath --value $UNIT)"
# The property that actually matters, tested by doing it: the account the
# scheduler runs as can replace files in the connector's state directory,
# which is www-data's and which the refresh has to rename over.
on "the service user can write $WEBROOT/signbank_data" \
   "touch $WEBROOT/signbank_data/.pctest && rm -f $WEBROOT/signbank_data/.pctest"

section "pythonCron: the demo's job list, not production's"
on "$PC_HOME/config.json is a symlink to $PC_CONF/config.json" \
   "test \"\$(readlink $PC_HOME/config.json)\" = $PC_CONF/config.json"
says "one job configured" "1" \
     "python3 -c \"import json;print(len(json.load(open('$PC_CONF/config.json'))))\""
says "and it is the Signbank ECV refresh" "Signbank ECV refresh" \
     "python3 -c \"import json;print(json.load(open('$PC_CONF/config.json'))[0]['service_name'])\""
# The three production jobs whose paths do exist here and would otherwise run.
for j in matchVicon.py convert.py syncEafToDatabase.php; do
  on "production job $j is not scheduled" "! grep -q $j $PC_CONF/config.json"
done
# PYTHONCRON_STATE_DIR as the unit sets it. Without it the scheduler falls
# back to writing its log beside its own code, and /opt/pythonCron is
# root-owned - which is the intended arrangement, not a fault, but it means a
# hand-run has to say where the writable half is.
says "the scheduler validated it" "Status: VALID" \
     "cd $PC_HOME && PYTHONCRON_STATE_DIR=$PC_STATE python3 scheduler_v2.py \
      --config $PC_CONF/config.json --validate-config"

section "pythonCron: the job has actually run"
sql="python3 -c \"import sqlite3;c=sqlite3.connect('$PC_STATE/scheduler_state.db');print(list(c.execute('select %s from %s')))\""
says "the job is a row in the scheduler database" "Signbank ECV refresh" \
     "$(printf "$sql" "service_name" "service_records")"
says "its last execution completed" "completed" \
     "$(printf "$sql" "status" "service_records")"
says "with exit code 0" "0" \
     "$(printf "$sql" "exit_code" "execution_history")"
says "and no consecutive failures" "(0,)" \
     "$(printf "$sql" "consecutive_failures" "service_records")"
says "the job log records the run" "Signbank ECV refresh" \
     "cat $PC_STATE/Signbank_ECV_refresh.log"

# ========================================================================
section "the connector page drives the schedule"
# The scheduler polls hourly; ecv_refresh.php decides whether a rebuild is
# due. Stopped for the duration, so setting the schedule to hourly for one
# assertion cannot let a tick start a real refresh.
ssh "$HOST" "sudo systemctl stop $UNIT" >/dev/null 2>&1
restore() { ssh "$HOST" "sudo systemctl start $UNIT" >/dev/null 2>&1; }
trap restore EXIT

sched() { # sched <off|hourly> - returns the API's own due/reason verdict
  curl -sS -H "Cookie: $COOK" -H 'Content-Type: application/json' \
       -X POST -d "{\"action\":\"schedule\",\"schedule\":\"$1\"}" \
       --max-time 30 "$BASE$API" 2>/dev/null
}
r=$(sched off)
case "$r" in *'"schedule_due":false'*) ok "schedule off: the API reports not due" ;;
  *) bad "schedule off: $r" ;; esac
says "and the job itself agrees, without contacting Signbank" "not due: schedule is off" \
     "cd $WEBROOT/menu_beta/signbank_sync && php ecv_refresh.php"
on   "the job exits 0, so the scheduler does not see a failure" \
     "cd $WEBROOT/menu_beta/signbank_sync && php ecv_refresh.php >/dev/null"

r=$(sched hourly)
case "$r" in *'"schedule_due":true'*) ok "schedule hourly: the API reports due" ;;
  *) bad "schedule hourly: $r" ;; esac
says "and the job would rebuild on its next tick" "true" \
     "php -r 'require \"$WEBROOT/menu_beta/signbank_sync/ecv_refresh.php\";
              echo signbank_schedule_due()[0] ? \"true\" : \"false\";'"

r=$(sched off)
case "$r" in *'"schedule_due":false'*) ok "restored to off" ;;
  *) bad "could not restore the schedule to off: $r" ;; esac
restore; trap - EXIT
says "scheduler running again" active "systemctl is-active $UNIT"

printf '\n\033[1m%s\033[0m  via %s\n' "$BASE" "$HOST"
printf 'passed %d   failed %d\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then printf '\nfailures:\n'; printf '  - %s\n' "${FAILURES[@]}"; fi
exit $(( fail > 0 ))
