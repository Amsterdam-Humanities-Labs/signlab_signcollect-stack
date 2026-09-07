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
# Prerequisites on the target: apache2 + php + mysql, /web writable by the
# ssh user, and a demo database. This script deploys the interface; it does
# not provision the server or seed the database (see db/ for the schema).
set -euo pipefail

cd "$(dirname "$0")/.."
HOST=${HOST:-demovps}
DOMAIN=${DOMAIN:-dev.taila8bdbd.ts.net}
echo "=== installing SignCollect demo ==="
echo "  host:   $HOST"
echo "  domain: $DOMAIN"
echo

# 1. Obtain the code. Fresh clones each run would be slower but this keeps
#    build/ reusable; clone.sh hard-resets so it is never a stale tree.
scripts/clone.sh

# 2. Point the code at this demo. Rewriting build/ in place means a redeploy
#    to a different DOMAIN must re-run clone.sh first - which install.sh
#    always does, in that order, for exactly this reason.
echo
echo "== rewriting production URLs =="
DOMAIN="$DOMAIN" scripts/rewrite-urls.sh build/*/ web_extra/

# 3. Strip the parts of production the demo must not carry.
echo
echo "== purging artifacts =="
scripts/purge-artifacts.sh build/*/ web_extra/ || true
python3 scripts/remove-mocap-tile.py build/signlab_signCollect-v2/index.html || true

# 4. Ship it.
echo
HOST="$HOST" scripts/deploy.sh

# 5. Server config. Idempotent - overwrites its own two files and nothing else.
echo
echo "== apache config =="
for f in apache/*.conf; do
  scp -q "$f" "$HOST:/tmp/$(basename "$f")"
  ssh "$HOST" "sudo mv /tmp/$(basename "$f") /etc/apache2/conf-available/ && \
               sudo a2enconf $(basename "$f" .conf) >/dev/null"
  echo "  enabled $(basename "$f")"
done
ssh "$HOST" 'sudo apache2ctl configtest && sudo systemctl reload apache2'

echo
echo "== verify =="
scripts/verify.sh "https://$DOMAIN" || true
