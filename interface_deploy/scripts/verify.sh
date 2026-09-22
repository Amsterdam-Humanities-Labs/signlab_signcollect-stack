#!/usr/bin/env bash
# Verify a demo deployment. Evidence, not assumptions - every claim here is a
# command whose output you can read.
#
# Both parameters are required and neither has a default. The one that used
# to be here named demovps, which has since been decommissioned, so a bare
# run spent its time SSHing at a machine that no longer exists and then
# reported the timeout as a failure of the demo.
#
# Usage: scripts/verify.sh --host gomer@demo1 https://demo1.example.org
#        scripts/verify.sh --host gomer@demo1            # base URL from --domain
set -uo pipefail

cd "$(dirname "$0")/.."
SC_USAGE='usage: scripts/verify.sh --host <ssh-target> [<base-url> | --domain <name>]'
# shellcheck source=scripts/_common.sh
. scripts/_common.sh
sc_parse_common "$@"
sc_require_host
B=""
[ ${#sc_args[@]} -gt 0 ] && B=${sc_args[0]}
[ -n "$B" ] || { sc_resolve_domain; B="https://$DOMAIN"; }
fail=0
chk() { # chk <path> <expected-code> <label>
  local got; got=$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 12 --max-time 30 "$B$1" 2>/dev/null)
  if [ "$got" = "$2" ]; then printf '  ok   %-32s %s\n' "$1" "$got"
  else printf '  FAIL %-32s got %s want %s\n' "$1" "$got" "$2"; fail=1; fi
}
echo "== pages =="
for p in / /index.html /menu_beta/index.html \
         /zin/zinnen.html /media/ /login.html; do chk "$p" 200; done
echo "== interface components =="
for p in /videoFix/index.html /studioIndex/ /hh/index.html /nmm/fastView.html \
         /downloadVideos/downloadThemaVideo.html /menu_beta/users.html \
         /menu_beta/labels_add.html /menu_beta/batch_add.html \
         /menu_beta/activity.html; do chk "$p" 200; done
# /stats.html was a one-off static Chart.js report of media-server download
# logs, generated 2026-07-06 and never regenerated, reached from a menu entry
# labelled "Gebruikersactiviteit" - which is not what it showed. menu_beta's
# activity.html replaces it and reads the activity_log table live, so the old
# file is gone and must stay gone.
chk /stats.html 404
# /api is the signlab_sCAPI submodule - a separate service, out of scope for
# an interface-only deploy. One endpoint (/zin/api/getSamVideos.php) is called
# from two places and will not work without it.
echo "== annotation editor =="
for p in /annotation-tool/ /annotation-tool/v1/ /annotation-tool/v2/ \
         /annotation-tool/v3/ /annotation-tool/webcam/ \
         /annotation-tool/clusters/ /annotation-tool/clusters/tool/; do chk "$p" 200; done
# The annotation editor ships five times over - v1, v2, v3, webcam and the
# copy under clusters/ - and each loads ffmpeg.wasm's 32MB core by a relative
# URL of its own. That core is not in git: four identical copies of it were,
# and scripts/fetch-ffmpeg-core.sh puts a hash-verified one on the host
# instead. Its absence does not break a page load, which is exactly why it is
# checked here - it breaks the first video conversion, minutes later, in a
# console message nobody is looking at. Asserted by length, because a 404 from
# this Apache is an HTML error page that a naive 200-check would not catch and
# a truncated download would pass anyway.
echo "== annotation editor: ffmpeg.wasm core =="
chklen() { # chklen <path> <bytes>
  local got
  got=$(curl -sSI --connect-timeout 12 --max-time 30 "$B$1" 2>/dev/null \
        | awk 'tolower($1)=="content-length:"{gsub(/\r/,"",$2); n=$2} END{print n+0}')
  if [ "$got" = "$2" ]; then printf '  ok   %-52s %s bytes\n' "$1" "$got"
  else printf '  FAIL %-52s got %s want %s\n' "$1" "$got" "$2"; fail=1; fi
}
for d in v1 v2 v3 webcam clusters/tool; do
  chklen "/annotation-tool/$d/vendor/ffmpeg/esm/ffmpeg-core.wasm" 32129114
done
# The loaders beside it. Tracked upstream in v1..webcam, so this is really
# about clusters/tool, whose whole vendor/ directory only exists because the
# deploy makes it - and about the module worker, which ffmpeg.js fetches by a
# name no `src=` grep would ever have found.
for f in ffmpeg.js util.js 814.ffmpeg.js esm/ffmpeg-core.js; do
  chk "/annotation-tool/clusters/tool/vendor/ffmpeg/$f" 200
done

# The Signbank ECV dump every gloss lookup reads, installed by host-config.sh
# from assets/. menu_beta's Glos Wizard, its batch entry page and nmm's
# scripts all resolve it at this absolute path, so a 404 here is silent -
# they get an HTML error page where they expect JSON.
echo "== signbank export =="
chk /signbank_data/glosses_transformed.json 200
echo "== secrets must be denied =="
for p in /mysql_config.php /zin/mysql_config.php /zin/.env /.env; do chk "$p" 403; done
echo "== isolation from production =="
for t in https://signcollect.nl/ https://136.144.170.87/ http://100.88.38.8/; do
  if ssh "$HOST" "curl -sS -o /dev/null --connect-timeout 6 $t" >/dev/null 2>&1; then
    printf '  FAIL reachable: %s\n' "$t"; fail=1
  else printf '  ok   blocked   %s\n' "$t"; fi
done
echo "== login (users is the one deliberately non-empty table) =="
r=$(curl -sS --connect-timeout 12 --max-time 30 -X POST -d "username=gomer&password=123" "$B/login_sc.php" 2>/dev/null)
case "$r" in *'"status":"success"'*) echo "  ok   gomer/123 authenticates" ;;
             *) echo "  FAIL login: $r"; fail=1 ;; esac
r=$(curl -sS --connect-timeout 12 --max-time 30 -X POST -d "username=gomer&password=wrong" "$B/login_sc.php" 2>/dev/null)
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
