#!/usr/bin/env bash
# Verify the demovps deployment. Evidence, not assumptions - every claim here
# is a command whose output you can read.
set -uo pipefail
B=${1:-https://dev.taila8bdbd.ts.net}
fail=0
chk() { # chk <path> <expected-code> <label>
  local got; got=$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 12 "$B$1" 2>/dev/null)
  if [ "$got" = "$2" ]; then printf '  ok   %-32s %s\n' "$1" "$got"
  else printf '  FAIL %-32s got %s want %s\n' "$1" "$got" "$2"; fail=1; fi
}
echo "== pages =="
for p in / /index.html /menu_beta/index.html "/menu_old/menu.html?extern=1" \
         /zin/zinnen.html /api/ /media/ /login.html; do chk "$p" 200; done
echo "== known-dead link (matches production) =="
chk /opnameViewTest.html 404
echo "== secrets must be denied =="
for p in /mysql_config.php /zin/mysql_config.php /api/mysql_config.php /zin/.env; do chk "$p" 403; done
echo "== isolation from production =="
for t in https://signcollect.nl/ https://136.144.170.87/ http://100.88.38.8/; do
  if ssh demovps "curl -sS -o /dev/null --connect-timeout 6 $t" >/dev/null 2>&1; then
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
echo "== database: 98 objects =="
ssh demovps 'sudo mysql -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=\"admin_gebarenoverleg\";"' \
  | awk '{ if ($1==98) print "  ok   objects = 98"; else { print "  FAIL objects = "$1; exit 1 } }' || fail=1
echo
[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $fail
