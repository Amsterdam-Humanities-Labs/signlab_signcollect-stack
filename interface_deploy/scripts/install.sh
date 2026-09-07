#!/usr/bin/env bash
# One command to stand the SignCollect demo up on a VPS - this one or a new one.
#
# Everything comes from GitHub: the seven component repos listed in
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
echo
echo "== purging artifacts =="
scripts/purge-artifacts.sh build/*/ || true
python3 scripts/remove-mocap-tile.py build/signlab_signCollect-v2/index.html || true

# 4. Ship it.
echo
HOST="$HOST" scripts/deploy.sh

# 5. Per-host configs that are gitignored upstream, so a clone never has them.
echo
echo "== host config =="
HOST="$HOST" scripts/host-config.sh

echo
echo "== verify =="
scripts/verify.sh "https://$DOMAIN" || true
