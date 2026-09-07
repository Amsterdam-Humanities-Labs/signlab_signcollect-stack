#!/usr/bin/env bash
# Tests for the install-root resolver - signcollect-lib's paths.php and the
# vendored sc_paths.php shim every consumer repository carries.
#
# The estate used to name /web as a string literal in 232 places. Those are
# now sc_path() / sc_dir() calls against one configurable root, and this file
# exists to assert the two halves of that claim:
#
#   - the root is configurable. SC_WEB_ROOT, as a constant, an environment
#     variable or a line in the env file, moves every path at once, and the
#     library's own location is a last resort before the compiled default;
#   - and yet nothing moved. The default is /web, so every call returns the
#     exact bytes the literal it replaced contained. The other four suites
#     are the real evidence for that - they are supposed to notice nothing -
#     and what is checked here is the string equality directly, because a
#     suite that only exercises endpoints cannot tell "still /web" from
#     "wrong, but nothing looked".
#
# It also guards the mistake this migration could most plausibly have made:
# rewriting a browser URL. href="/zin/zinnen.html" and
# fetch('/signbank_data/...') are relative to DocumentRoot and stay correct
# when the filesystem root moves. Those are asserted to be untouched, and the
# deployed tree is asserted to contain no /web/ prefix where a URL belongs.
#
# Read-only: nothing here writes to the host outside /tmp, and no test
# changes the deployed root. Never point it at production anyway.
#
# Usage: BASE=https://dev2.taila8bdbd.ts.net HOST=gomer@dev2 tests/path-test.sh
#
# HOST is optional. Without it the on-host half is skipped and reported as
# such, the same way mocap-test.sh handles its egress checks.
set -uo pipefail

BASE=${BASE:-https://dev2.taila8bdbd.ts.net}
HOST=${HOST:-}
WEBROOT=${WEBROOT:-/web}

pass=0; fail=0; skip=0
declare -a FAILURES

case "$BASE" in *signcollect.nl*) echo "refusing to run against production"; exit 2 ;; esac

ok()   { pass=$((pass+1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
bad()  { fail=$((fail+1)); FAILURES+=("$1"); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
note() { skip=$((skip+1)); printf '  --   %s\n' "$1"; }
section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

code() { curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$BASE$1" 2>/dev/null; }
body() { curl -sS --max-time 20 "$BASE$1" 2>/dev/null; }

is() { # is <label> <path> <code>...
  local label=$1 path=$2; shift 2
  local got; got=$(code "$path")
  for c in "$@"; do [ "$got" = "$c" ] && { ok "$label ($got)"; return; }; done
  bad "$label (got $got, want ${*})"
}
eq() { # eq <label> <got> <want>
  [ "$2" = "$3" ] && ok "$1" || bad "$1 - got '$2', want '$3'"
}
# One php -r on the host, with the deployed library.
onhost() { ssh -o ConnectTimeout=10 "$HOST" "$1" 2>/dev/null; }

# --- 1. the resolver is a library, not a page ---------------------------
# /web/lib is denied wholesale by its own .htaccess. The vendored shims sit
# inside document trees and are therefore reachable, which is fine as long as
# apache executes them: they define functions, print nothing, and have no
# side effects. What must never happen is apache handing back their source.
section "the resolver is not servable"
is "/lib/paths.php denied" /lib/paths.php 403
is "/lib/consumer/sc_paths.php denied" /lib/consumer/sc_paths.php 403
for p in /sc_paths.php /zin/sc_paths.php /hh/sc_paths.php /menu_beta/sc_paths.php; do
  b=$(body "$p")
  case "$b" in
    *'<?php'*|*'function sc_path'*) bad "$p discloses its source" ;;
    '') ok "$p executes and prints nothing" ;;
    *) bad "$p returned a body: $(printf '%s' "$b" | head -c 100)" ;;
  esac
done

# --- 2. the default really is /web -------------------------------------
section "default root"
if [ -z "$HOST" ]; then
  note "on-host resolver checks skipped - set HOST=<ssh target> to run them"
else
  R=$(onhost 'php -r "require \"/web/lib/paths.php\"; echo sc_root();"')
  eq "sc_root() is $WEBROOT" "$R" "$WEBROOT"

  # Each of these is a literal that used to be typed out somewhere in the
  # estate. They are compared as strings, not as "a path that exists",
  # because the claim under test is byte equality with what was deleted.
  read -r -d '' PROBE <<'PHP'
require "/web/lib/paths.php";
echo implode("\n", [
  sc_path("mysql_config.php"),
  sc_path(".session_secret"),
  sc_path("signbank_data/glosses_transformed.json"),
  sc_path("glosses_transformed.json"),
  sc_path("uploads"),
  sc_path("uploads/lsm"),
  sc_dir("uploads"),
  sc_dir("media_raw"),
  sc_dir("media_post"),
  sc_dir("media_fbx"),
  sc_dir("media_fbx", "cc_pipeline"),
  sc_dir("media", "razerFiles"),
  sc_dir("zin/eaf/zin"),
  sc_dir("hh/eaf"),
  sc_dir(),
  sc_url("/web/zin/eaf/zin/x.srt"),
  sc_url("/mnt/bigstorage/x.mkv"),
]);
PHP
  GOT=$(onhost "php -r '$PROBE'")
  WANT=$(cat <<EOF
$WEBROOT/mysql_config.php
$WEBROOT/.session_secret
$WEBROOT/signbank_data/glosses_transformed.json
$WEBROOT/glosses_transformed.json
$WEBROOT/uploads
$WEBROOT/uploads/lsm
$WEBROOT/uploads/
$WEBROOT/gebarenoverleg_media/studioFilesMini/raw/
$WEBROOT/gebarenoverleg_media/studioFilesMini/post/
$WEBROOT/gebarenoverleg_media/fbx/
$WEBROOT/gebarenoverleg_media/fbx/cc_pipeline/
$WEBROOT/gebarenoverleg_media/razerFiles/
$WEBROOT/zin/eaf/zin/
$WEBROOT/hh/eaf/
$WEBROOT/
/zin/eaf/zin/x.srt

EOF
)
  if [ "$GOT" = "$WANT" ]; then
    ok "every resolved path is byte-identical to the literal it replaced (17 probes)"
  else
    bad "resolved paths differ from the old literals"
    diff <(printf '%s' "$WANT") <(printf '%s' "$GOT") | sed 's/^/       /'
  fi

  # The directories those calls name must actually be there. A resolver that
  # agrees with itself and points at nothing is still broken.
  for d in gebarenoverleg_media/studioFilesMini/raw gebarenoverleg_media/studioFilesMini/post \
           signbank_data uploads lib zin hh; do
    onhost "test -e $WEBROOT/$d" && ok "$WEBROOT/$d exists" || bad "$WEBROOT/$d is missing"
  done
fi

# --- 3. the root is genuinely configurable ------------------------------
# Phase 2 moves the root. Prove the mechanism now, on a throwaway value, so
# that the move is a configuration change rather than a discovery.
section "the root is configurable"
if [ -z "$HOST" ]; then
  note "override checks skipped - no HOST"
else
  G=$(onhost 'SC_WEB_ROOT=/srv/demo php -r "require \"/web/lib/paths.php\"; echo sc_root(), \"|\", sc_dir(\"media_raw\"), \"|\", sc_url(\"/srv/demo/zin/x.srt\");"')
  eq "SC_WEB_ROOT moves the root, the named locations and sc_url() together" \
     "$G" "/srv/demo|/srv/demo/gebarenoverleg_media/studioFilesMini/raw/|/zin/x.srt"

  G=$(onhost 'php -r "define(\"SC_WEB_ROOT\", \"/opt/sc\"); require \"/web/lib/paths.php\"; echo sc_root();"')
  eq "the SC_WEB_ROOT constant wins over the compiled default" "$G" "/opt/sc"

  # Step 3 of the documented order: the env file. Written to /tmp and pointed
  # at with SC_ENV_FILE, so the host's own /web/.env is never touched.
  G=$(onhost 'f=$(mktemp); printf "DB_HOST=localhost\nDB_USER=u\nDB_NAME=n\nSC_WEB_ROOT=/tmp/rootfromenv\n" > $f; SC_ENV_FILE=$f php -r "require \"/web/lib/paths.php\"; echo sc_root();"; rm -f $f')
  eq "SC_WEB_ROOT in the env file moves the root" "$G" "/tmp/rootfromenv"

  # A relative root is refused rather than resolved against the cwd of
  # whatever cron job happened to call it.
  G=$(onhost 'SC_WEB_ROOT=not/absolute php -r "require \"/web/lib/paths.php\"; echo sc_root();" 2>/dev/null')
  eq "a relative SC_WEB_ROOT falls back to the compiled default" "$G" "/web"

  # Step 4: installed as <root>/lib, the parent is the root, with nothing set.
  G=$(onhost 'd=$(mktemp -d); mkdir -p $d/lib; cp /web/lib/paths.php /web/lib/db_config.php $d/lib/; php -r "require \"$d/lib/paths.php\"; echo sc_root();"; rm -rf $d')
  case "$G" in
    /*/lib) bad "a library at <x>/lib resolved the root to itself: $G" ;;
    /tmp/*|/var/folders/*) ok "a library installed at <x>/lib resolves the root to <x> ($G)" ;;
    *) bad "unexpected root for a relocated library: $G" ;;
  esac
fi

# --- 4. the vendored shims are one file ---------------------------------
# Thirteen copies of consumer/sc_paths.php ship inside thirteen repositories,
# because several of them also deploy to production, which has no /web/lib.
# Copies drift; a checksum is the only thing that keeps them from doing it.
section "vendored shims"
if [ -z "$HOST" ]; then
  note "shim checksum skipped - no HOST"
else
  N=$(onhost "ls $WEBROOT/sc_paths.php $WEBROOT/*/sc_paths.php 2>/dev/null | wc -l" | tr -d ' ')
  U=$(onhost "md5sum $WEBROOT/lib/consumer/sc_paths.php $WEBROOT/sc_paths.php $WEBROOT/*/sc_paths.php 2>/dev/null | awk '{print \$1}' | sort -u | wc -l" | tr -d ' ')
  [ "${N:-0}" -ge 10 ] && ok "$N vendored shims are deployed" \
                       || bad "only ${N:-0} vendored shims found - expected at least 10"
  eq "every vendored shim is byte-identical to the library's original" "$U" "1"

  # And the fallback the shim exists for: with the library out of reach, it
  # must still answer /web rather than fatal. open_basedir is the cheapest
  # way to make /web/lib unreadable to one process without touching the host.
  G=$(onhost "cp $WEBROOT/sc_paths.php /tmp/sc_paths_probe.php; php -d open_basedir=/tmp -r 'require \"/tmp/sc_paths_probe.php\"; echo sc_root(), \"|\", sc_dir(\"media_post\");' 2>/dev/null; rm -f /tmp/sc_paths_probe.php")
  eq "the shim answers on a host with no library at all" \
     "$G" "/web|/web/gebarenoverleg_media/studioFilesMini/post/"
fi

# --- 5. nothing still hardcodes the root --------------------------------
# The survivors are legitimate and bounded: the shim's own search for the
# library, and the two credential bootstraps that have the same
# chicken-and-egg problem. Anything else is a literal that got missed.
section "no stray literals"
if [ -z "$HOST" ]; then
  note "deployed-tree scan skipped - no HOST"
else
  # Two exclusions, both deliberate, both about files this repository does
  # not ship:
  #
  #   signbank_sync/config.php is written per host by host-config.sh and
  #   excluded from every rsync. Its state_dir is an absolute path on
  #   purpose - a config file is exactly where an absolute path belongs, and
  #   client.php falls back to sc_path('signbank_data') when it is absent.
  #
  #   */api/ is not deployed at all. deploy.sh excludes 'api/' so that
  #   --delete cannot wipe the sCAPI submodule mounted at /web/zin/api, and
  #   rsync matches that pattern at every depth, so /web/viconDashboard/api
  #   is excluded too. The four files there are stale copies predating this
  #   migration; the repository's own versions are migrated. See the note
  #   below - it is a deploy bug, not a missed literal.
  STRAY=$(onhost "grep -rn --include='*.php' -E \"['\\\"]/web/\" $WEBROOT 2>/dev/null \
      | grep -v '^$WEBROOT/lib/' \
      | grep -v '/signbank_sync/config.php:' \
      | grep -v '/api/' \
      | grep -vE ':[0-9]+: *(\\*|//|#)' \
      | grep -v '/web/lib/'")
  if [ -z "$STRAY" ]; then
    ok "every remaining /web literal in deployed PHP is a library-discovery path"
  else
    bad "$(printf '%s' "$STRAY" | wc -l | tr -d ' ') stray hardcoded path(s) in deployed PHP"
    printf '%s\n' "$STRAY" | head -10 | sed 's/^/       /'
  fi

  # Say out loud what the exclusion above hides, so it cannot quietly become
  # permanent: viconDashboard's four API endpoints are migrated in git and
  # unreachable by rsync.
  APISTALE=$(onhost "grep -rln --include='*.php' \"'/web/mysql_config.php'\" $WEBROOT/*/api 2>/dev/null | tr '\n' ' '")
  [ -n "$APISTALE" ] && note "not deployed, so still hardcoded on the host: $APISTALE(deploy.sh's --exclude 'api/' matches at every depth)"
fi

# --- 6. browser URLs were not touched -----------------------------------
# This is the way the migration goes wrong. A URL that starts /web/ is a
# 404, and a filesystem path handed to the browser is a broken video.
section "browser URLs are untouched"
b=$(body /zin/zinnen.html)
case "$b" in
  *'/web/'*) bad "/zin/zinnen.html contains a /web/ prefixed URL" ;;
  *) ok "/zin/zinnen.html has no /web/ prefixed URL" ;;
esac
for p in /signbank_data/glosses_transformed.json /zin/zinnen.html /hh/index.html \
         /menu_beta/index.html /nmm/fastView.html; do
  is "still served: $p" "$p" 200
done
if [ -n "$HOST" ]; then
  # zin/iss_client/test.html is the one pre-existing offender: two of its
  # fetches carry a /web/ prefix and have therefore always 404'd. It predates
  # this migration by a long way and fixing it would be a behaviour change,
  # so it is named here rather than silently swept into the pattern - the
  # assertion is that this list does not grow.
  U=$(onhost "grep -rlE '(href|src|fetch\\(|url\\()[\"'\\''( ]*/web/' --include='*.html' --include='*.js' --include='*.css' $WEBROOT 2>/dev/null \
      | grep -v '/zin/iss_client/test.html$' | head -5")
  [ -z "$U" ] && ok "no browser URL acquired a /web/ prefix" \
              || bad "browser URL with a /web/ prefix in: $(printf '%s' "$U" | tr '\n' ' ')"
  note "pre-existing, not touched: /zin/iss_client/test.html fetches two /web/-prefixed URLs"
fi

# --- 7. the endpoints whose paths moved still answer --------------------
# Every one of these opens a file through the resolver. They are checked
# unauthenticated on purpose: a 401 proves the file loaded and the auth check
# ran, which is exactly what a broken require_once would have prevented.
section "endpoints that resolve a path"
for p in "/zin/getZinnen.php?action=listMocapFiles" "/hh/getGlosses.php?action=search&term=boek" \
         /hh/api.php /menu_beta/php_api/current_user.php \
         "/zin/getSenses.php?glos=BOEK" /studio_beta/zin/getSenses.php; do
  is "loads and authenticates: $p" "$p" 200 400 401 403
done
# A 500 anywhere above would be the signature of a shim that could not be
# found; check explicitly so the message says so.
for p in "/zin/getZinnen.php?action=listMocapFiles" /hh/api.php /menu_beta/php_api/current_user.php; do
  [ "$(code "$p")" = 500 ] && bad "500 from $p - the resolver shim did not load" || true
done

# --- summary ------------------------------------------------------------
printf '\n\033[1m%s\033[0m\n' "$BASE"
printf 'passed %d   failed %d   notes %d\n' "$pass" "$fail" "$skip"
if [ "$fail" -gt 0 ]; then
  printf '\nfailures:\n'; printf '  - %s\n' "${FAILURES[@]}"
fi
exit $(( fail > 0 ))
