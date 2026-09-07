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
sc_on_error "scripts/provision.sh $(sc_retry_args)"
DB=admin_gebarenoverleg
DBUSER=signcollect

echo "=== provisioning $(sc_where) as $DOMAIN, into $WEBROOT ==="

# --- 1. LAMP ------------------------------------------------------------
# php-mysql pulls mysqli + pdo_mysql, which is what the interface uses.
sc_doing "installing packages (apache, php, mysql, git, ...)" \
  "apt failed on the host. Usually a stale index or no outbound HTTPS.
     Look:  ssh $HOST 'sudo apt-get update'"
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
  # nftables is what scripts/isolate.sh loads the egress block into. Ubuntu
  # ships it by default and the demo would work without it right up to the
  # moment it mattered, which is precisely the kind of dependency worth
  # naming rather than inheriting.
  for p in apache2 php libapache2-mod-php php-mysql php-mbstring php-curl \
           php-gd php-xml php-zip php-bz2 mysql-server git curl nftables \
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
sc_doing "creating $WEBROOT and its writable directories"
ssh "$HOST" 'set -e
  sudo mkdir -p '"$WEBROOT"' '"$WEBROOT"'/media_stub '"$WEBROOT"'/uploads '"$WEBROOT"'/uploads/lsm
  sudo chown -R "$USER":www-data '"$WEBROOT"'
  sudo chmod 2775 '"$WEBROOT"' '"$WEBROOT"'/uploads '"$WEBROOT"'/uploads/lsm
  [ -f '"$WEBROOT"'/media_stub/index.html ] || echo "media stub" | sudo tee '"$WEBROOT"'/media_stub/index.html >/dev/null
  echo "  '"$WEBROOT"' ready"'

# --- 3. database + credentials -----------------------------------------
# .env is created only once; a re-run must not invalidate the password the
# database already has.
sc_doing "creating the database and $WEBROOT/.env" \
  "The database password is generated on the host and written to $WEBROOT/.env once.
     If .env exists but the grant is wrong, remove it and re-run to reissue both."
ssh "$HOST" "set -e
  if [ ! -f '"$WEBROOT"'/.env ]; then
    pw=\$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
    sudo mysql -e \"CREATE DATABASE IF NOT EXISTS $DB CHARACTER SET utf8mb4;\"
    sudo mysql -e \"CREATE USER IF NOT EXISTS '$DBUSER'@'localhost' IDENTIFIED BY '\$pw';\"
    sudo mysql -e \"ALTER USER '$DBUSER'@'localhost' IDENTIFIED BY '\$pw';\"
    sudo mysql -e \"GRANT ALL PRIVILEGES ON $DB.* TO '$DBUSER'@'localhost'; FLUSH PRIVILEGES;\"
    printf 'DB_HOST=localhost\nDB_USER=$DBUSER\nDB_PASS=%s\nDB_NAME=$DB\nSC_WEB_ROOT='"$WEBROOT"'\n' \"\$pw\" > '"$WEBROOT"'/.env
    chmod 640 '"$WEBROOT"'/.env; sudo chown \"\$USER\":www-data '"$WEBROOT"'/.env
    echo '  database created, '"$WEBROOT"'/.env written with SC_WEB_ROOT (password not shown)'
  else
    sudo mysql -e \"CREATE DATABASE IF NOT EXISTS $DB CHARACTER SET utf8mb4;\"
    echo '  '"$WEBROOT"'/.env already exists - left alone'
  fi"

# --- 4. schema + demo login --------------------------------------------
# Loaded only into an empty database. Re-running must never drop live demo
# data, so a non-zero object count means hands off.
sc_doing "loading db/schema.sql"
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
sc_doing "creating the database and $WEBROOT/.env" \
  "The database password is generated on the host and written to $WEBROOT/.env once.
     If .env exists but the grant is wrong, remove it and re-run to reissue both."
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
# Every apache file is a template now: DocumentRoot, the /api and /media
# aliases and the deny rules all sit below the install root, so they have to
# follow --webroot or apache serves a directory the deploy never wrote to.
#
# Rendered straight onto the host through sc_put, with no workstation-side
# staging file. What was here before was
#
#     sed t > /tmp/$out; scp /tmp/$out "$HOST:/tmp/$out"; rm -f /tmp/$out
#
# which reads as three steps only because the two machines are different.
# Run with --local the source and the destination are one path: cp refused
# ("are the same file") and the rm that followed would have deleted the file
# the next step reads. sc_put has a destination and no source, so there is no
# second path to collide with and nothing to clean up - see _common.sh.
#
# The staging directory is emptied first rather than written into: a rename
# of a template between releases would otherwise leave its rendered output in
# /tmp for a2enconf to pick up forever.
sc_doing "staging the apache configuration on the host" \
  "Nothing has been enabled yet; the previous apache config is untouched."
ssh "$HOST" 'rm -rf /tmp/signcollect-apache && mkdir -p /tmp/signcollect-apache'
sed -e "s|@DOMAIN@|$DOMAIN|g" -e "s|@WEBROOT@|$WEBROOT|g" \
    apache/vhost-ssl.conf.template | sc_put /tmp/signcollect-apache/demo-ssl.conf
for f in apache/signcollect-*.conf.template; do
  out=$(basename "$f" .template)
  sed -e "s|@WEBROOT@|$WEBROOT|g" "$f" | sc_put "/tmp/signcollect-apache/$out"
done

sc_doing "enabling the apache configuration" \
  "apache2ctl configtest rejected the rendered config, or apache would not reload.
     Look:  ssh $HOST 'sudo apache2ctl configtest; sudo journalctl -u apache2 -n 30'"
ssh "$HOST" 'set -e
  cd /tmp/signcollect-apache
  sudo install -o root -g root -m 644 demo-ssl.conf /etc/apache2/sites-available/demo-ssl.conf
  sudo a2ensite demo-ssl >/dev/null 2>&1 || true
  for f in signcollect-*.conf; do
    [ -e "$f" ] || continue
    sudo install -o root -g root -m 644 "$f" /etc/apache2/conf-available/"$f"
    sudo a2enconf "$(basename "$f" .conf)" >/dev/null
  done
  cd /; rm -rf /tmp/signcollect-apache
  sudo apache2ctl configtest && sudo systemctl reload apache2
  echo "  apache configured"'

echo "=== provisioning complete ==="
