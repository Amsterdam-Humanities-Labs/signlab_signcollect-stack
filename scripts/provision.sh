#!/usr/bin/env bash
# Provision a bare Ubuntu host into a SignCollect demo server: LAMP, docroot,
# database, TLS, apache config, credentials.
#
# Idempotent - every step checks before it acts, so re-running is safe and
# only fills in what is missing. install.sh calls this first.
#
#   --host <ssh-target>   required
#   --domain <name>       optional; read off the host with `tailscale status`
#
# TLS comes from `tailscale cert`, which only issues for the node's own
# MagicDNS name - so DOMAIN must be that name, or the cert step is skipped
# and you supply a certificate yourself. That is also why DOMAIN defaults to
# whatever the host calls itself rather than to a hostname written here: a
# name this file guessed could never match a certificate the host can issue.
#
# The database password is generated on the target and written to /web/.env.
# It is never printed here and never leaves the host.
set -euo pipefail

cd "$(dirname "$0")/.."
SC_USAGE='usage: scripts/provision.sh --host <ssh-target> [--domain <name>]'
# shellcheck source=scripts/_common.sh
. scripts/_common.sh
sc_parse_common "$@"
sc_require_host
sc_resolve_domain
DB=admin_gebarenoverleg
DBUSER=signcollect

echo "=== provisioning $HOST as $DOMAIN ==="

# --- 1. LAMP ------------------------------------------------------------
# php-mysql pulls mysqli + pdo_mysql, which is what the interface uses.
ssh "$HOST" 'set -e
  need=""
  # Extension set matched against production. php-mbstring is not optional:
  # labels_create.php calls mb_strlen() and dies with "undefined function"
  # without it, so label creation fails and every gloss that references a
  # label then fails too. php-curl/gd/xml/zip match the production set of
  # non-default extensions.
  #
  # composer is installed from apt rather than downloaded because this half
  # of the job belongs to the machine: a tool the host needs, once, from the
  # same package manager as everything else. There are no runtime
  # dependencies for it to fetch - animMIDI, the one component with a
  # composer.json, requires only PHP extensions, which are above. What it is
  # for is composer dump-autoload, which writes the PSR-4 autoloader that
  # nine files under animMIDI/public/ require on their first line. That
  # generation step is deliberately NOT here: it belongs to
  # scripts/host-bootstrap.sh, which can only run it once the code is on the
  # host, which at this point it is not.
  #
  # python3-psutil is the only third-party import in the scheduler pythonCron
  # runs here: lib/health_monitor uses it to kill stuck jobs and report
  # process memory. Without it python-scheduler.service crash-loops on
  # ImportError and nothing scheduled ever runs. See scripts/pythoncron.sh.
  #
  # Both of these are machine-level, which is why they are in this file at
  # all: apt packages a host needs once, not artefacts of a deploy.
  #
  # rsync used to be on this list and is deliberately gone. Nothing installs
  # it and nothing calls it: the docroot is built by the host itself out of
  # git checkouts (scripts/host-bootstrap.sh), and the demo host this now
  # targets does not permit rsync at all. git, by the same change, went from
  # a convenience to the single most load-bearing package here.
  for p in apache2 php libapache2-mod-php php-mysql php-mbstring php-curl \
           php-gd php-xml php-zip php-bz2 mysql-server git curl \
           composer python3-psutil; do
    dpkg -s "$p" >/dev/null 2>&1 || need="$need $p"
  done
  if [ -n "$need" ]; then
    echo "  installing:$need"
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $need
  else
    echo "  packages already present"
  fi
  sudo a2enmod rewrite ssl >/dev/null 2>&1 || true
  sudo systemctl enable --now apache2 mysql >/dev/null 2>&1 || true'

# --- 2. docroot ---------------------------------------------------------
# uploads/ and uploads/lsm are not incidental: php_api/upload_video.php and
# php_api/lsm_video_upload.php write there, and the browser plays recordings
# back from /uploads/<hash>.webm - i.e. straight out of DocumentRoot. On
# production /web/uploads has always existed as a symlink to bulk storage, so
# a host built from scratch was the only place the assumption showed up, as a
# 500 on the first selfie recording.
ssh "$HOST" 'set -e
  sudo mkdir -p /web /web/media_stub /web/uploads /web/uploads/lsm
  sudo chown -R "$USER":www-data /web
  sudo chmod 2775 /web /web/uploads /web/uploads/lsm
  [ -f /web/media_stub/index.html ] || echo "media stub" | sudo tee /web/media_stub/index.html >/dev/null
  echo "  /web ready"'

# --- 3. database + credentials -----------------------------------------
# .env is created only once; a re-run must not invalidate the password the
# database already has.
ssh "$HOST" "set -e
  if [ ! -f /web/.env ]; then
    pw=\$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
    sudo mysql -e \"CREATE DATABASE IF NOT EXISTS $DB CHARACTER SET utf8mb4;\"
    sudo mysql -e \"CREATE USER IF NOT EXISTS '$DBUSER'@'localhost' IDENTIFIED BY '\$pw';\"
    sudo mysql -e \"ALTER USER '$DBUSER'@'localhost' IDENTIFIED BY '\$pw';\"
    sudo mysql -e \"GRANT ALL PRIVILEGES ON $DB.* TO '$DBUSER'@'localhost'; FLUSH PRIVILEGES;\"
    printf 'DB_HOST=localhost\nDB_USER=$DBUSER\nDB_PASS=%s\nDB_NAME=$DB\n' \"\$pw\" > /web/.env
    chmod 640 /web/.env; sudo chown \"\$USER\":www-data /web/.env
    echo '  database created, /web/.env written (password not shown)'
  else
    sudo mysql -e \"CREATE DATABASE IF NOT EXISTS $DB CHARACTER SET utf8mb4;\"
    echo '  /web/.env already exists - left alone'
  fi"

# --- 4. schema + demo login --------------------------------------------
# Loaded only into an empty database. Re-running must never drop live demo
# data, so a non-zero object count means hands off.
objs=$(ssh "$HOST" "sudo mysql -N -e \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB';\"")
if [ "${objs:-0}" -eq 0 ]; then
  # innodb_strict_mode must be off for this dump. form_data is 68 columns of
  # latin1 varchar, whose inline row exceeds InnoDB's 8126-byte limit; with
  # strict mode on, MySQL 8 refuses it outright (ERROR 1118) instead of
  # letting DYNAMIC row format push the overflow off-page. Production and
  # the earlier demo host both ended up with it as DYNAMIC, so this matches.
  { echo "SET SESSION innodb_strict_mode=OFF;"; cat db/schema.sql; } \
    | ssh "$HOST" "sudo mysql $DB"
  echo "  schema loaded"
else
  echo "  database already has $objs objects - not reloaded"
fi
# Always applied: demo-user.sql is ON DUPLICATE KEY UPDATE, and it refreshes
# last_login, which login_sc.php uses to auto-block accounts idle 60+ days.
ssh "$HOST" "sudo mysql $DB" < db/demo-user.sql
echo "  demo login ensured"

# --- 5. TLS -------------------------------------------------------------
ssh "$HOST" "set -e
  if [ ! -f /etc/ssl/demo/\$(basename $DOMAIN).crt ]; then
    sudo mkdir -p /etc/ssl/demo
    if sudo tailscale cert --cert-file /etc/ssl/demo/$DOMAIN.crt \
                           --key-file  /etc/ssl/demo/$DOMAIN.key $DOMAIN 2>/dev/null; then
      echo '  tailscale cert issued'
    else
      echo '  WARNING: tailscale cert failed - supply a cert at /etc/ssl/demo/$DOMAIN.{crt,key}'
    fi
  else
    echo '  cert already present'
  fi"

# --- 6. apache config ---------------------------------------------------
sed "s|@DOMAIN@|$DOMAIN|g" apache/vhost-ssl.conf.template > /tmp/vhost-$DOMAIN.conf
scp -q /tmp/vhost-$DOMAIN.conf "$HOST:/tmp/demo-ssl.conf"; rm -f /tmp/vhost-$DOMAIN.conf
for f in apache/*.conf; do scp -q "$f" "$HOST:/tmp/$(basename "$f")"; done
ssh "$HOST" 'set -e
  sudo mv /tmp/demo-ssl.conf /etc/apache2/sites-available/demo-ssl.conf
  sudo a2ensite demo-ssl >/dev/null 2>&1 || true
  for f in /tmp/signcollect-*.conf; do
    [ -e "$f" ] || continue
    sudo mv "$f" /etc/apache2/conf-available/
    sudo a2enconf "$(basename "$f" .conf)" >/dev/null
  done
  sudo apache2ctl configtest && sudo systemctl reload apache2
  echo "  apache configured"'

echo "=== provisioning complete ==="
