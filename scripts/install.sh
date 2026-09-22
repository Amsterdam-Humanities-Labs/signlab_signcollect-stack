#!/usr/bin/env bash
# One command to stand the SignCollect demo up on a VPS - this one or a new one.
#
#   scripts/install.sh --host gomer@demo1
#
# That is the whole thing. See README.md for what a host needs first (ssh
# access, passwordless sudo, tailscale joined, GitHub reachable).
#
# WHAT THIS IS NOW
#
# An SSH orchestrator, and nothing else. No file of the deployed tree passes
# through this workstation any more:
#
#   workstation:  push to GitHub  ->  ssh host, run the bootstrap
#   host:         clone 17 repos  ->  rewrite-urls.sh  ->  purge  ->  serve
#
# It used to clone the components here, rewrite their production URLs here,
# and rsync 500MB up on every run. rsync is not installed on the new demo
# host and is not going to be; the workstation was a single point of failure
# for a deploy anybody should be able to run; and macOS, being
# case-insensitive, silently dropped two of signlab_hh's 7661 files on every
# single deploy because it tracks vitamine-D.json and vitamine-d.json side by
# side. Cloning on the host fixes all three at once.
#
# The reason the copy existed at all was the URL rewrite - the deployed tree
# is deliberately not the git tree, because a plain checkout would serve
# https://api.signcollect.nl and give the demo a route back to production.
# That rewrite now runs on the host, in scripts/host-bootstrap.sh, between
# the clone and the first request. scripts/verify.sh still asserts the
# isolation it buys.
#
# Every step is idempotent, so this is also the normal way to redeploy an
# already-running demo - and, just as importantly, the way to resume one that
# stopped half way. A second run converges; it does not compound. Each step
# checks before it acts: packages are compared against dpkg, the database is
# reloaded only when empty, .env and .session_secret are written once and then
# left alone, every component checkout is fetch + reset --hard rather than a
# clone that would refuse a non-empty directory, and migrations are recorded in
# schema_migrations so they are applied once.
#
# NOTHING IS TOUCHED BEFORE PREFLIGHT PASSES
#
# Step 1 asks the host every question the other ten depend on - can we log in,
# does sudo work without a password, can it reach github.com, is there a
# certificate name to be had, is there disk, is anything already sitting on
# 443 - and reports all of them at once, with the command that fixes each. It
# changes nothing, so it is also the safe thing to run against a host you are
# unsure of: scripts/preflight.sh --host <target>.
#
# --dry-run stops after that and prints what the run WOULD change, read off
# the host as it is now.
set -euo pipefail

cd "$(dirname "$0")/.."
SC_USAGE='usage: scripts/install.sh (--host <ssh-target> | --local) [--domain <name>]
                          [--webroot <path>] [--no-provision] [--dry-run]

  --host    <target> ssh target for the demo host, e.g. gomer@demo1
  --local            run everything on this machine instead of over ssh. Use
                     it when you are already on the demo host: clone the stack
                     repo, cd into interface_deploy, and run this.
  --domain  <name>   hostname the demo is served as.  Optional: it is read
                     from the host with `tailscale status --self`, which is
                     the only name `tailscale cert` will issue for anyway.
  --webroot <path>   absolute path to install into.  Default /web.  It becomes
                     apache DocumentRoot, the parent of the /api and /media
                     mounts, and SC_WEB_ROOT in the env file - so the PHP
                     resolver and the deploy always agree on one location.
                     Choose it at install time; moving it later means moving
                     the tree and re-running with the new value.
  --no-provision     skip step 2 when the server is known-good.
  --dry-run          run the preflight checks, report what would change, and
                     stop without changing anything.

HOST and DOMAIN are still honoured as environment variables.

Example, taking a bare Ubuntu box to a working demo:
  scripts/install.sh --host gomer@100.69.94.19

  Somewhere other than /web:
    scripts/install.sh --host gomer@100.69.94.19 --webroot /srv/signcollect/web

  Run on the demo host itself, no ssh:
    scripts/install.sh --local --webroot /srv/signcollect/web

  See what it would do, without doing it:
    scripts/install.sh --host gomer@100.69.94.19 --dry-run'
# shellcheck source=scripts/_common.sh
. scripts/_common.sh

provision=1
sc_parse_common "$@"
for a in ${sc_args+"${sc_args[@]}"}; do
  case "$a" in
    --no-provision) provision=0 ;;
    *) sc_die "unknown argument: $a" ;;
  esac
done
SC_DRY_OK=1              # this script is the one that implements --dry-run
sc_require_host

# --- progress, and what to do when a step stops -----------------------------
# The steps were already numbered in comments. Numbering them in the output
# too is what makes a failure locatable: "it died at 6/11" is a sentence you
# can act on, where a wall of undifferentiated apt and git output is not.
NSTEPS=11
step=0
say() { step=$((step+1)); STEPNAME=$1; printf '\n[%d/%d] %s\n' "$step" "$NSTEPS" "$1"; }
STEPNAME=startup
trap 'rc=$?; [ $rc -eq 0 ] || {
  printf "\n=== install FAILED at step %d/%d: %s ===\n" "$step" "$NSTEPS" "$STEPNAME" >&2
  printf "    host: %s   webroot: %s\n\n" "$(sc_where)" "$WEBROOT" >&2
  printf "    Nothing after this step ran. The steps that did run are idempotent,\n" >&2
  printf "    so fix the cause reported above and re-run the whole install - it\n" >&2
  printf "    will skip what is already done rather than redo it:\n\n" >&2
  printf "      scripts/install.sh %s\n\n" "$(sc_retry_args)" >&2
}' EXIT

# --- 1. preflight -----------------------------------------------------------
say "preflight - checking the host before anything is changed"
scripts/preflight.sh || exit 1

# Asks the host its own MagicDNS name unless --domain said otherwise. Getting
# this wrong does not fail loudly - DOMAIN lands in cookie domains and in the
# redirect allow-lists in login.html / logout.html - so it is derived rather
# than defaulted. After preflight, because preflight is what explains a host
# with no tailscale in terms of what to type next.
STEPNAME="working out what the demo is served as"
sc_resolve_domain
export HOST DOMAIN WEBROOT

echo
echo "=== installing SignCollect demo ==="
echo "  host:    $(sc_where)"
echo "  domain:  $DOMAIN"
echo "  webroot: $WEBROOT"
echo "  source:  $SRCDIR"

# --- --dry-run --------------------------------------------------------------
# Honest, because every line of it is read off the host as it is right now
# rather than predicted from the scripts. It says what each step would find
# and therefore what it would do; it does not simulate the doing.
if [ "${SC_DRY:-0}" = "1" ]; then
  echo
  echo "=== dry run: what this would change on $(sc_where) ==="
  ncomp=$(grep -cvE '^[[:space:]]*(#|$)' scripts/repos.tsv)
  ssh "$HOST" "
    set +e
    W='$WEBROOT'
    miss=''
    for p in apache2 php libapache2-mod-php php-mysql php-mbstring php-curl \
             php-gd php-xml php-zip php-bz2 mysql-server git curl nftables \
             composer python3-psutil; do
      dpkg -s \"\$p\" >/dev/null 2>&1 || miss=\"\$miss \$p\"
    done
    if [ -n \"\$miss\" ]; then echo \"  2 provision   would apt-get install:\$miss\"
    else echo '  2 provision   all packages present'; fi
    [ -d \"\$W\" ] && echo \"  2 provision   \$W exists\" || echo \"  2 provision   would create \$W (+ uploads, media_stub)\"
    [ -f \"\$W/.env\" ] && echo '  2 provision   .env present - password and SC_WEB_ROOT left alone' \
                       || echo '  2 provision   would create the database, a password, and .env'
    n=\$(sudo mysql -N -e \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='admin_gebarenoverleg';\" 2>/dev/null)
    [ \"\${n:-0}\" -gt 0 ] && echo \"  2 provision   database has \${n} objects - schema NOT reloaded\" \
                          || echo '  2 provision   database empty - would load db/schema.sql'
    ls /etc/ssl/demo/*.crt >/dev/null 2>&1 && echo '  2 provision   TLS cert present' \
                                           || echo '  2 provision   would issue a tailscale cert'
    [ -e /etc/apache2/sites-enabled/demo-ssl.conf ] && echo '  2 provision   apache vhost enabled - would be re-rendered and reloaded' \
                                                    || echo '  2 provision   would enable the apache vhost'
    if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
      echo \"  3 host-auth   gh already logged in as \$(gh api user -q .login 2>/dev/null)\"
    else echo '  3 host-auth   would install gh and give it a GitHub login'; fi
    have=0
    while IFS=\$'\t' read -r d r b; do
      case \"\$d\" in ''|\\#*) continue ;; esac
      [ -e \"\$W/\$d/.git\" ] && have=\$((have+1))
    done < \"$SRCDIR/scripts/repos.tsv\" 2>/dev/null
    echo \"  5 bootstrap   \$have of $ncomp components already checked out; every one would be fetched and reset --hard, then URL-rewritten for $DOMAIN\"
    grep -q signcollect-isolation /etc/hosts 2>/dev/null && echo '  6 isolate     already applied - would be re-applied' \
                                                         || echo '  6 isolate     would null-route and firewall production off this host'
    [ -f \"\$W/.session_secret\" ] && echo '  7 host-config .session_secret present - left alone' \
                                  || echo '  7 host-config would generate .session_secret'
    [ -f \"\$W/signbank_data/glosses_transformed.json\" ] && echo '  7 host-config gloss dump present - left alone' \
                                  || echo '  7 host-config would seed the gloss dump from assets/'
    s=\$(systemctl is-active python-scheduler.service 2>/dev/null)
    echo \"  8 pythoncron  scheduler is \${s:-absent}; /opt/pythonCron would be replaced\"
    a=\$(sudo mysql -N admin_gebarenoverleg -e 'SELECT COUNT(*) FROM schema_migrations;' 2>/dev/null)
    f=\$(ls -1 \"\$W\"/menu_beta/migrations/*.sql 2>/dev/null | wc -l | tr -d ' ')
    echo \"  9 migrate     \${a:-0} of \${f:-?} migrations recorded as applied\"
    c=\$(sudo mysql -N admin_gebarenoverleg -e 'SELECT COUNT(*) FROM CameraRecords;' 2>/dev/null)
    echo \" 10 seed        CameraRecords holds \${c:-0} rows; demo rows are re-applied idempotently\"
  "
  echo
  echo "  Nothing above has been changed. To do it:"
  echo "    scripts/install.sh $(sc_retry_args)"
  echo
  trap - EXIT
  exit 0
fi

# --- 2. the server ----------------------------------------------------------
# LAMP, docroot, database, TLS, apache - all idempotent. This is also where
# git arrives, which everything after it needs.
if [ $provision -eq 1 ]; then
  say "provision - packages, docroot, database, TLS, apache"
  scripts/provision.sh
else
  say "provision - skipped (--no-provision)"
fi

# --- 3. credentials ---------------------------------------------------------
# The host clones ~17 private org repos now, so it needs a login of its own.
say "host-auth - a GitHub login for the host"
scripts/host-auth.sh

# --- 4. this repo, on the host ----------------------------------------------
# scripts/, web_extra/, assets/, db/, config/ and apache/ all have to be
# reachable from the host for the bootstrap to run there rather than here.
# With --local they already are, and this step says so and does nothing.
say "host-src - the deploy tree where the host can read it"
scripts/host-src.sh

# --- 5. the docroot ---------------------------------------------------------
# Clone, rewrite, purge, place - all on the host.
say "bootstrap - clone 17 components, rewrite URLs, place vendored files"
ssh "$HOST" "DOMAIN='$DOMAIN' WEBROOT='$WEBROOT' $SRCDIR/scripts/host-bootstrap.sh"

# --- 6. isolation -----------------------------------------------------------
# This used to be a step you were expected to remember, and on a host where it
# had been forgotten the only symptom was verify.sh's isolation block turning
# red at the very end - after everything else had passed, which is the point in
# a deploy where a failure is least likely to be read. A demo that can still
# reach signcollect.nl is not a demo, so it is part of the install now.
#
# Runs on the host, as the host: it writes /etc/hosts and loads an nftables
# table there. The chain policy stays ACCEPT and only production's addresses
# are rejected, so it cannot cut our own SSH.
say "isolate - cut every path from this demo to production"
ssh "$HOST" "$SRCDIR/scripts/isolate.sh" | sed 's/^/  /'

# --- 7. per-host config -----------------------------------------------------
# The files that are gitignored upstream, so a clone never has them.
say "host-config - the per-host files no clone carries"
scripts/host-config.sh

# --- 8. scheduled jobs ------------------------------------------------------
# pythonCron is not a docroot component - it is a systemd service - so it has
# neither a repos.tsv row nor a place in the bootstrap, and clones itself to
# /opt instead. See scripts/pythoncron.sh.
#
# After host-config.sh, not before: the one job it schedules writes the
# Signbank gloss dump, which needs $WEBROOT/signbank_data to exist and the
# deploy user to be in group www-data, and both are that script's doing.
#
# Not fatal. A demo whose scheduler failed to install is still a demo - the
# connector's "Ververs nu" button does not go through pythonCron - and
# stopping here would leave the deploy unverified.
say "pythoncron - the job scheduler at /opt/pythonCron"
if scripts/pythoncron.sh; then :; else
  echo "  WARNING: pythonCron not installed - the Signbank refresh will not run on a schedule."
  echo "  The connector page still refreshes on demand. Re-run:"
  echo "    scripts/pythoncron.sh $(sc_retry_args)"
fi

# --- 9. migrations ----------------------------------------------------------
# db/schema.sql is a point-in-time dump; anything added since exists only in
# migrations/, and the interface breaks without them. They are read off the
# host, out of the deployed menu_beta checkout, because that is where
# signlab_signCollect-v2 lands.
say "migrate - SQL migrations from the deployed checkout"
scripts/migrate.sh

# --- 10. demo data ----------------------------------------------------------
# After migrations, because those can still add columns these rows write into.
#
# The media no longer moves: signlab_demo-media is an ordinary component, so
# the bootstrap has already cloned its 291MB straight into
# $WEBROOT/gebarenoverleg_media. All this does is the SQL and the hard links
# into media_stub.
#
# Not fatal: a missing or incomplete checkout should leave the demo up with an
# empty database rather than abort the deploy before it is verified.
say "seed - demo rows, and the media hard links"
if scripts/seed-demo-data.sh; then :; else
  echo "  WARNING: seeding failed - the interface is deployed but has no demo data."
  echo "  Re-run: scripts/seed-demo-data.sh $(sc_retry_args)"
fi

# --- 11. verify -------------------------------------------------------------
say "verify - assert the result, by command output not assumption"
if scripts/verify.sh --host "$HOST" "https://$DOMAIN"; then
  verdict="=== demo installed: https://$DOMAIN ==="
else
  verdict="=== demo installed at https://$DOMAIN, but verify.sh reported failures above ==="
fi
trap - EXIT
echo
echo "$verdict"
echo "  log in as gomer / 123"
echo "  redeploy any time with the same command - every step is idempotent:"
echo "    $PWD/scripts/install.sh $(sc_retry_args)"

# Someone installing on the demo machine's own desktop is looking at a
# terminal with a browser one click away; open it for them. Over ssh, or on
# a console with no graphical session, there is nothing to open.
if [ "${SC_LOCAL:-0}" = "1" ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] &&
   command -v xdg-open >/dev/null 2>&1; then
  xdg-open "https://$DOMAIN/" >/dev/null 2>&1 &
fi
