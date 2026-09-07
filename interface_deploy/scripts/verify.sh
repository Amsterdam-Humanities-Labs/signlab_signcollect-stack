#!/usr/bin/env bash
# Verify the demovps deployment. Evidence, not assumptions - every claim here
# is a command whose output you can read.
set -uo pipefail
B=${1:-https://dev.taila8bdbd.ts.net}
HOST=${HOST:-demovps}   # ssh target, for the checks that must run on the box
fail=0
chk() { # chk <path> <expected-code> <label>
  local got; got=$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 12 "$B$1" 2>/dev/null)
  if [ "$got" = "$2" ]; then printf '  ok   %-32s %s\n' "$1" "$got"
  else printf '  FAIL %-32s got %s want %s\n' "$1" "$got" "$2"; fail=1; fi
}
echo "== pages =="
for p in / /index.html /menu_beta/index.html "/menu_old/menu.html?extern=1" \
         /zin/zinnen.html /media/ /login.html; do chk "$p" 200; done
echo "== interface components =="
for p in /videoFix/index.html /studioIndex/ /hh/index.html /nmm/fastView.html \
         /downloadVideos/downloadThemaVideo.html /menu_beta/users.html \
         /menu_beta/labels_add.html /menu_beta/batch_add.html /stats.html; do chk "$p" 200; done
# /api is the signlab_sCAPI submodule - a separate service, out of scope for
# an interface-only deploy. One endpoint (/zin/api/getSamVideos.php) is called
# from two places and will not work without it.
echo "== known-dead link (matches production) =="
chk /opnameViewTest.html 404
echo "== secrets must be denied =="
for p in /mysql_config.php /zin/mysql_config.php /zin/.env /.env; do chk "$p" 403; done
echo "== isolation from production =="
for t in https://signcollect.nl/ https://136.144.170.87/ http://100.88.38.8/; do
  if ssh "$HOST" "curl -sS -o /dev/null --connect-timeout 6 $t" >/dev/null 2>&1; then
    printf '  FAIL reachable: %s\n' "$t"; fail=1
  else printf '  ok   blocked   %s\n' "$t"; fi
done
echo "== login (users is the one deliberately non-empty table) =="
r=$(curl -sS --connect-timeout 12 -X POST -d "username=gomer&password=123" "$B/login_sc.php" 2>/dev/null)
case "$r" in *'"status":"success"'*) echo "  ok   gomer/123 authenticates" ;;
             *) echo "  FAIL login: $r"; fail=1 ;; esac
r=$(curl -sS --connect-timeout 12 -X POST -d "username=gomer&password=wrong" "$B/login_sc.php" 2>/dev/null)
case "$r" in *'"status":"failure"'*) echo "  ok   wrong password rejected" ;;
             *) echo "  FAIL bad password not rejected: $r"; fail=1 ;; esac
# 98 from db/schema.sql, plus schema_migrations, which scripts/migrate.sh
# creates to record what it has applied.
echo "== database: 99 objects =="
ssh "$HOST" 'sudo mysql -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=\"admin_gebarenoverleg\";"' \
  | awk '{ if ($1==99) print "  ok   objects = 99"; else { print "  FAIL objects = "$1" (want 99)"; exit 1 } }' || fail=1
echo
[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $fail
