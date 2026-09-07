#!/usr/bin/env bash
# Install the per-host config files that are gitignored upstream and so never
# arrive with a clone.
#
# Runs AFTER deploy.sh, because these live inside deployed component
# directories. Never overwrites an existing file - a host that already has a
# real config keeps it.
#
# Usage: HOST=demovps scripts/host-config.sh
set -euo pipefail

cd "$(dirname "$0")/.."
HOST=${HOST:-demovps}

# signbank_sync/config.php - php_api/current_user.php calls signbank_config()
# on every page load, and it throws when the file is missing, which surfaces
# in the UI as "Init failed: Internal Server Error".
if ssh "$HOST" 'test -f /web/menu_beta/signbank_sync/config.php'; then
  echo "  signbank_sync/config.php already present - left alone"
else
  scp -q config/signbank_sync.demo.php "$HOST:/tmp/sbconfig.php"
  ssh "$HOST" 'mkdir -p /web/menu_beta/signbank_sync &&
               mv /tmp/sbconfig.php /web/menu_beta/signbank_sync/config.php &&
               sudo chown "$USER":www-data /web/menu_beta/signbank_sync/config.php &&
               chmod 640 /web/menu_beta/signbank_sync/config.php'
  echo "  signbank_sync/config.php installed (demo values, no real credential)"
fi

# /web/.session_secret - signs the session cookie. Without it session.php
# falls back to accepting an unsigned cookie, which is what let a hand-written
# {"userId":38} impersonate that user. Generated once and never rotated here:
# rotating it logs everyone out.
if ssh "$HOST" 'test -s /web/.session_secret'; then
  echo "  .session_secret already present - left alone"
else
  ssh "$HOST" 'umask 027 && openssl rand -hex 32 > /web/.session_secret &&
               sudo chown "$USER":www-data /web/.session_secret &&
               chmod 640 /web/.session_secret'
  echo "  .session_secret generated (value not shown)"
fi
