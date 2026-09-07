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

# The annotation editors are each their own docroot with a zin/ beneath, so
# they resolve mysql_config.php one level above zin/ and again at zin/api/.
# Symlinks to the real /web/mysql_config.php rather than copies, so there is
# still one credential file on the host.
for ed in subBeta8 3DAnn3; do
  ssh "$HOST" "set -e
    d=/web/annotation-editors/$ed
    [ -d \"\$d\" ] || exit 0
    mkdir -p \"\$d/zin/api\" \"\$d/zin/cache\" \"\$d/zin/eaf/zin\"
    ln -sfn /web/mysql_config.php \"\$d/mysql_config.php\"
    ln -sfn /web/mysql_config.php \"\$d/zin/api/mysql_config.php\"
    chmod 775 \"\$d/zin/cache\" \"\$d/zin/eaf/zin\" 2>/dev/null || true"
  echo "  annotation-editors/$ed: mysql_config symlinked, runtime dirs ready"
done

# /web/glosses_transformed.json - the Signbank gloss export, ~10.5MB of JSON.
#
# Read by absolute path from the docroot root by several components
# (signCollect-v2 get_glosses.php, signlab_zin getSenses.php, signlab_hh
# getGlosses.php, the annotation tool), so it has to exist at exactly this
# path. It was 404 on the demo, which broke every one of them.
#
# It ships from assets/ rather than a component tree because it belongs to no
# single component - it is shared data that four of them read - and deploy.sh
# only carries component directories plus web_extra's root files.
#
# rsync, not scp: it is re-sent as a delta when it changes and is a no-op when
# it has not, which matters for a file this size on every redeploy. -a keeps
# the 644 and lands it gomer:staff, the same as the other /web root files.
#
# Production carries four byte-identical copies - /web, menu_old/,
# blendBaking/, hh/ - plus a stale half-size one under helpScripts/test/ from
# 2024 that is a test fixture, not the export. Only the docroot root copy is
# deployed here; every component resolves it by absolute path, so the
# duplicates buy nothing.
rsync -a assets/glosses_transformed.json "$HOST:/web/glosses_transformed.json"
echo "  glosses_transformed.json installed ($(wc -c < assets/glosses_transformed.json) bytes)"
