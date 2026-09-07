#!/usr/bin/env bash
# One command to stand the SignCollect demo up on a VPS - this one or a new one.
#
# Everything comes from GitHub: the component repos listed in
# repos.tsv, plus the vendored web_extra/ and apache/ trees in this repo.
# Nothing is pulled from signcollect.nl, so this runs from any checkout.
#
#   HOST    ssh target for the VPS            (default: demovps)
#   DOMAIN  hostname the demo is served as    (default: dev.taila8bdbd.ts.net)
#
# Redeploying onto a different VPS is exactly:
#   HOST=demo2 DOMAIN=demo2.example.org scripts/install.sh
#
# A bare Ubuntu host is fine: step 0 installs the LAMP stack, creates the
# docroot and database, issues the TLS cert and writes the apache config.
# Every step is idempotent, so this is also the normal way to redeploy an
# already-running demo.
#
# Pass --no-provision to skip step 0 when the server is known-good.
set -euo pipefail

cd "$(dirname "$0")/.."
HOST=${HOST:-demovps}
DOMAIN=${DOMAIN:-dev.taila8bdbd.ts.net}
provision=1
[ "${1:-}" = "--no-provision" ] && provision=0
echo "=== installing SignCollect demo ==="
echo "  host:   $HOST"
echo "  domain: $DOMAIN"
echo

# 0. Server. LAMP, docroot, database, TLS, apache - all idempotent.
if [ $provision -eq 1 ]; then
  HOST="$HOST" DOMAIN="$DOMAIN" scripts/provision.sh
  echo
else
  echo "(skipping provision)"
fi

# 1. Obtain the code. Fresh clones each run would be slower but this keeps
#    build/ reusable; clone.sh hard-resets so it is never a stale tree.
scripts/clone.sh

# 2. Point the code at this demo. Rewriting build/ in place means a redeploy
#    to a different DOMAIN must re-run clone.sh first - which install.sh
#    always does, in that order, for exactly this reason.
echo
echo "== rewriting production URLs =="
DOMAIN="$DOMAIN" scripts/rewrite-urls.sh build/*/

# 3. Strip the parts of production the demo must not carry.
#    The Motion Capture menu tile used to be stripped here as well, because
#    mocap was out of scope. It is deployed now (see repos.tsv), so the tile
#    stays and rewrite-urls.sh points it at /mocap_site on this host.
echo
echo "== purging artifacts =="
scripts/purge-artifacts.sh build/*/ || true

# 4. Ship it.
echo
HOST="$HOST" scripts/deploy.sh

# 5. Per-host configs that are gitignored upstream, so a clone never has them.
echo
echo "== host config =="
HOST="$HOST" scripts/host-config.sh

# 5b. mocapStudio and animMIDI both resolve mysql_config.php next to
#     themselves rather than at the docroot, and that file is gitignored
#     upstream in each, so a clone never has it. Symlinked, not copied, so
#     there stays exactly one credential file on the host - the same trick
#     host-config.sh uses for the annotation editors. Re-made every run:
#     deploy.sh rsyncs both components with --delete.
#
#     animMIDI joined this list once its Composer autoloader existed. Before
#     that, every page under animMIDI/public/ died on line 2 requiring
#     vendor/autoload.php and no request ever reached a database call; with
#     the autoloader in place the next thing an authenticated admin hit was
#     app/config/Database.php requiring ../../mysql_config.php, which is the
#     identical gap one layer down. The two are separate bugs that looked
#     like one because the first hid the second.
#
#     viconDashboard/api/ needs shipping by hand for a different reason:
#     deploy.sh excludes 'api/' from every component so that rsync --delete
#     cannot wipe /web/zin/api (the sCAPI service it does not clone). That
#     pattern has no leading slash, so it matches api/ at any depth and takes
#     viconDashboard's four endpoints with it - the dashboard then renders but
#     every panel 404s. Sent separately here rather than loosening the exclude,
#     which is deploy.sh's to own.
echo
echo "== mocap config =="
if [ -d build/signlab_viconDashboard/api ]; then
  rsync -a --delete build/signlab_viconDashboard/api/ "$HOST:/web/viconDashboard/api/"
  echo "  viconDashboard/api/ shipped (deploy.sh excludes api/ everywhere)"
fi
ssh "$HOST" 'for c in mocapStudio animMIDI; do
    if [ -d "/web/$c" ]; then
      ln -sfn /web/mysql_config.php "/web/$c/mysql_config.php"
      echo "  $c/mysql_config.php -> /web/mysql_config.php"
    else
      echo "  /web/$c absent - skipped"
    fi
  done'

# 5c. Scheduled jobs. pythonCron is not a docroot component - it is a systemd
#     service - so it has neither a repos.tsv row nor a deploy.sh rsync, and
#     runs its own clone-to-/opt script instead. See scripts/pythoncron.sh for
#     where it lands and why.
#
#     After host-config.sh, not before: the one job it schedules writes the
#     Signbank gloss dump, which needs /web/signbank_data to exist and the
#     deploy user to be in group www-data, and both of those are that script's
#     doing. It also needs the job itself on disk, which is deploy.sh's.
#
#     Not fatal. A demo whose scheduler failed to install is still a demo -
#     the connector's "Ververs nu" button does not go through pythonCron - and
#     stopping here would leave the deploy unverified.
echo
if HOST="$HOST" DOMAIN="$DOMAIN" scripts/pythoncron.sh; then :; else
  echo "  WARNING: pythonCron not installed - the Signbank refresh will not run on a schedule."
  echo "  The connector page still refreshes on demand. Re-run:"
  echo "    HOST=$HOST DOMAIN=$DOMAIN scripts/pythoncron.sh"
fi

# 6. Schema migrations. db/schema.sql is a point-in-time dump; anything added
#    since exists only in migrations/, and the interface breaks without them.
echo
echo "== migrations =="
HOST="$HOST" scripts/migrate.sh

# 7. Demo data. After migrations, because those can still add columns these
#    rows write into.
#
#    The media comes from the signlab_demo-media component, cloned by step 1
#    like any other repo - nothing here reaches signcollect.nl. It used to
#    rsync from production into a local cache, which meant a fresh checkout
#    could only be seeded from a workstation with production access.
#
#    Not fatal: a missing or incomplete checkout should leave the demo up with
#    an empty database rather than abort the deploy before it has been verified.
echo
echo "== demo data =="
if HOST="$HOST" scripts/seed-demo-data.sh; then :; else
  echo "  WARNING: seeding failed - the interface is deployed but has no demo data."
  echo "  Check build/signlab_demo-media exists, then re-run:"
  echo "    scripts/clone.sh && HOST=$HOST scripts/seed-demo-data.sh"
fi

echo
echo "== verify =="
scripts/verify.sh "https://$DOMAIN" || true
