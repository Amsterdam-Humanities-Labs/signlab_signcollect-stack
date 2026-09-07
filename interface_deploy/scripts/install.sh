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
# already-running demo.
set -euo pipefail

cd "$(dirname "$0")/.."
SC_USAGE='usage: scripts/install.sh --host <ssh-target> [--domain <name>] [--no-provision]

  --host   <target>  ssh target for the demo host, e.g. gomer@demo1  (required)
  --domain <name>    hostname the demo is served as.  Optional: it is read
                     from the host with `tailscale status --self`, which is
                     the only name `tailscale cert` will issue for anyway.
  --no-provision     skip step 0 when the server is known-good.

HOST and DOMAIN are still honoured as environment variables.

Example, taking a bare Ubuntu box to a working demo:
  scripts/install.sh --host gomer@100.69.94.19'
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
sc_require_host
# Asks the host its own MagicDNS name unless --domain said otherwise. Getting
# this wrong does not fail loudly - DOMAIN lands in cookie domains and in the
# redirect allow-lists in login.html / logout.html - so it is derived rather
# than defaulted.
sc_resolve_domain
export HOST DOMAIN

echo "=== installing SignCollect demo ==="
echo "  host:   $HOST"
echo "  domain: $DOMAIN"
echo

# 0. Server. LAMP, docroot, database, TLS, apache - all idempotent. This is
#    also where git arrives, which everything after it needs.
if [ $provision -eq 1 ]; then
  scripts/provision.sh
  echo
else
  echo "(skipping provision)"
fi

# 1. Credentials for GitHub. The host clones ~17 private org repos now, so it
#    needs a login of its own; this hands it one from your gh token. Proven
#    on dev2 and reused unchanged.
scripts/host-auth.sh
echo

# 2. This repo, on the host. scripts/, web_extra/, assets/, db/, config/ and
#    apache/ all have to be reachable from the host for the bootstrap to run
#    there rather than here.
scripts/host-src.sh
echo

# 3. The docroot. Clone, rewrite, purge, place - all on the host.
echo "== bootstrap (on $HOST) =="
ssh "$HOST" "DOMAIN='$DOMAIN' ${WEBROOT:+WEBROOT='$WEBROOT'} $SRCDIR/scripts/host-bootstrap.sh"

# 3b. Cut the demo off from production. This used to be a step you were
#     expected to remember, and on a host where it had been forgotten the
#     only symptom was verify.sh's isolation block turning red at the very
#     end - after everything else had passed, which is the point in a deploy
#     where a failure is least likely to be read. A demo that can still reach
#     signcollect.nl is not a demo, so it is part of the install now.
#
#     Runs on the host, as the host: it writes /etc/hosts and loads an
#     nftables table there. The chain policy stays ACCEPT and only
#     production's addresses are rejected, so it cannot cut our own SSH.
echo
echo "== isolation from production =="
ssh "$HOST" "$SRCDIR/scripts/isolate.sh" | sed 's/^/  /'

# 4. Per-host configs that are gitignored upstream, so a clone never has them.
echo
echo "== host config =="
scripts/host-config.sh

# 5. Scheduled jobs. pythonCron is not a docroot component - it is a systemd
#    service - so it has neither a repos.tsv row nor a place in the bootstrap,
#    and clones itself to /opt instead. See scripts/pythoncron.sh.
#
#    After host-config.sh, not before: the one job it schedules writes the
#    Signbank gloss dump, which needs /web/signbank_data to exist and the
#    deploy user to be in group www-data, and both are that script's doing.
#
#    Not fatal. A demo whose scheduler failed to install is still a demo -
#    the connector's "Ververs nu" button does not go through pythonCron - and
#    stopping here would leave the deploy unverified.
echo
if scripts/pythoncron.sh; then :; else
  echo "  WARNING: pythonCron not installed - the Signbank refresh will not run on a schedule."
  echo "  The connector page still refreshes on demand. Re-run:"
  echo "    scripts/pythoncron.sh --host $HOST --domain $DOMAIN"
fi

# 6. Schema migrations. db/schema.sql is a point-in-time dump; anything added
#    since exists only in migrations/, and the interface breaks without them.
#    They are read off the host now, out of the deployed menu_beta checkout,
#    because that is where signlab_signCollect-v2 lands.
echo
echo "== migrations =="
scripts/migrate.sh

# 7. Demo data. After migrations, because those can still add columns these
#    rows write into.
#
#    The media no longer moves: signlab_demo-media is an ordinary component,
#    so the bootstrap has already cloned its 291MB straight into
#    /web/gebarenoverleg_media. All this does is the SQL and the hard links
#    into media_stub.
#
#    Not fatal: a missing or incomplete checkout should leave the demo up with
#    an empty database rather than abort the deploy before it is verified.
echo
echo "== demo data =="
if scripts/seed-demo-data.sh; then :; else
  echo "  WARNING: seeding failed - the interface is deployed but has no demo data."
  echo "  Re-run: scripts/seed-demo-data.sh --host $HOST"
fi

echo
echo "== verify =="
scripts/verify.sh --host "$HOST" "https://$DOMAIN" || true
