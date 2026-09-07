#!/usr/bin/env bash
# Deploy signlab_pythonCron - the job scheduler - onto the demo host.
#
# This is the only component that is not a directory under the docroot, so it
# is the only one that does not go through repos.tsv + clone.sh + deploy.sh.
# A repos.tsv row is not merely insufficient here, it is the wrong shape: that
# file maps a repo to /web/<webdir> and deploy.sh knows no other destination,
# so a row would rsync a systemd service into the docroot and publish its
# source over HTTP. It gets its own script instead.
#
#   HOST     ssh target                     (default: demovps)
#   DOMAIN   hostname the demo is served as (default: dev.taila8bdbd.ts.net)
#   WEBROOT  docroot on the target          (default: /web)
#
# ---------------------------------------------------------------------------
# Where it goes, and why
#
#   /opt/pythonCron       the code
#   /etc/opt/pythonCron   config.json - the list of jobs this host runs
#   /var/opt/pythonCron   scheduler_state.db, scheduler_v2.log, job logs
#
# The user asked for it out of /home/gomer, which it hardcoded upstream, and
# the FHS gives three candidates:
#
#   /opt is for "add-on application software packages" - self-contained
#     software that did not come from the distribution, installed as a unit
#     under its own directory. That is exactly what this is: a git checkout of
#     an application, deployed whole, owned by nobody but the admin. FHS also
#     supplies the other two halves of the answer, which is what settles it -
#     an /opt package's host configuration belongs in /etc/opt/<name> and its
#     variable data in /var/opt/<name>. Three directories, one rule.
#
#   /srv is "site-specific data served by this system" - the data a service
#     hands to users, /srv/www and /srv/ftp. pythonCron serves nothing to
#     anyone; it is a process that runs other processes. Its only output is
#     written into the docroot by the jobs themselves.
#
#   /usr/local is for software the administrator builds and installs locally,
#     and it is a bin/lib/share/etc hierarchy, not a place to drop an
#     application directory. FHS additionally wants /usr shareable and
#     read-only between hosts, which sits badly with a tree a deploy replaces.
#     There is nothing built here - it is Python source, rsynced.
#
# The split earns its keep beyond tidiness. /opt/pythonCron is rsync --delete
# and root-owned: a deploy replaces it wholesale, and the service user cannot
# rewrite its own code. /var/opt/pythonCron is never touched by the deploy,
# which matters because scheduler_state.db is the only record of when each job
# last ran - delete it and every job reads as never-executed and therefore due
# immediately, which for this job set means an unscheduled 7,500-request
# rebuild against a third party. Upstream needed a change to allow the split
# (PYTHONCRON_HOME / PYTHONCRON_STATE_DIR); it is in signlab_pythonCron.
#
# ---------------------------------------------------------------------------
# What is registered, and what deliberately is not
#
# pythonCron carries two schedulers that production runs side by side: the
# centralized scheduler_v2 (one process, config.json) and sixteen per-service
# wrapper units plus a watchdog (services_config.json). Only the first is
# installed here. The demo has exactly one job, the wrapper architecture would
# add eighteen systemd units to run it, and its own README warns that a job
# present in both files is scheduled twice.
#
# The job is the Signbank ECV refresh. signlab_signCollect-v2's
# signbank_sync/ecv_refresh.php names pythonCron as its scheduler in its
# header and prints the config.json entry it expects; config/pythoncron.demo.json
# is that entry, with the docroot parameterised. Nothing else from production's
# config.json comes along - three of its seventeen jobs have paths that do
# exist on this host (mocap/matchVicon.py, mocap/convert.py,
# zin/syncEafToDatabase.php) and would start running against demo data
# unasked. So the demo's job list is written here rather than taken from the
# repo, and /opt/pythonCron/config.json is replaced by a symlink to it, so
# that even a hand-run `python3 scheduler_v2.py` in that directory cannot pick
# up production's list.
#
# Running the job hourly does not mean refreshing hourly. ecv_refresh.php
# decides for itself whether a rebuild is due, from the schedule an admin sets
# on the connector page, which defaults to off - so out of the box each tick
# exits immediately with "not due: schedule is off" and Signbank is never
# contacted. That indirection is deliberate upstream: config.json belongs to a
# root-owned systemd unit and the web server must not have to rewrite it.
#
# Usage: HOST=demovps DOMAIN=demo.example.org scripts/pythoncron.sh
set -euo pipefail

cd "$(dirname "$0")/.."
HOST=${HOST:-demovps}
DOMAIN=${DOMAIN:-dev.taila8bdbd.ts.net}
WEBROOT=${WEBROOT:-/web}

ORG=Amsterdam-Humanities-Labs
REPO=signlab_pythonCron
BRANCH=main
UNIT=python-scheduler.service

PC_HOME=/opt/pythonCron
PC_CONF=/etc/opt/pythonCron
PC_STATE=/var/opt/pythonCron

echo "== pythonCron =="

# --- 1. the code --------------------------------------------------------
# Same idiom as clone.sh: hard reset rather than pull, so build/ is never a
# tree somebody edited by hand.
if [ -d "build/$REPO/.git" ]; then
  git -C "build/$REPO" fetch --quiet origin "$BRANCH"
  git -C "build/$REPO" checkout --quiet "$BRANCH"
  git -C "build/$REPO" reset --hard --quiet "origin/$BRANCH"
  act=updated
else
  gh repo clone "$ORG/$REPO" "build/$REPO" -- --branch "$BRANCH" --quiet
  act=cloned
fi
printf '  %-8s %-24s %s\n' "$act" "$REPO" "$(git -C "build/$REPO" rev-parse --short HEAD)"

# Not optional, even though nothing here is served over HTTP. Five files -
# checkDisk.py, rclone_monitor.py, sync_mocap_files.py, python_client.py and
# php_client.php - post monitoring results to https://signcollect.nl/... The
# demo host is firewalled from production and none of those five is scheduled,
# but "no code on this host names production" is worth keeping true as a fact
# rather than as a consequence of two other things being true.
DOMAIN="$DOMAIN" scripts/rewrite-urls.sh "build/$REPO"

# --- 2. directories -----------------------------------------------------
SVCUSER=$(ssh "$HOST" 'id -un')
ssh "$HOST" "set -e
  command -v systemctl >/dev/null || { echo '  no systemd on this host - cannot install $UNIT' >&2; exit 1; }
  sudo install -d -o root -g root -m 755 $PC_HOME $PC_CONF
  sudo install -d -o $SVCUSER -g $SVCUSER -m 755 $PC_STATE"
echo "  $PC_HOME (root), $PC_CONF (root), $PC_STATE ($SVCUSER) ready"

# root-owned, so rsync writes through sudo. The service user reads its code
# and cannot rewrite it.
#
# -rlpt, not the -a every other rsync in this repo uses, and then an explicit
# chown. -a additionally means -og, and unlike every other rsync here this
# one's receiver runs as root, so -og takes effect: it reproduces the
# workstation's numeric uid and gid on the target. On this demo host that
# happens to land on the deploy user, because OrbStack mirrors the macOS uid
# and 501:50 really is gomer:staff there - which is how a tree that was meant
# to be root-owned came out owned by the account the service runs as, looking
# entirely correct. On a VPS where the deploy user is uid 1000 it would have
# landed on some unrelated account or on nobody at all.
#
# So ownership is stated rather than inherited. --chown=root:root would say it
# in one flag, but macOS now ships openrsync, which does not have it, and this
# script has to run from a workstation. chown -R is the portable equivalent
# and is a no-op on every run after the first.
rsync -rlpt --delete --rsync-path='sudo rsync' \
  --exclude '.git' --exclude '__pycache__' --exclude 'node_modules' \
  "build/$REPO/" "$HOST:$PC_HOME/"
ssh "$HOST" "sudo chown -R root:root $PC_HOME"
echo "  code -> $PC_HOME"

# --- 3. this host's job list -------------------------------------------
# Installed on every run rather than left alone if present, unlike the configs
# host-config.sh writes. Those hold credentials and local decisions; this is
# the deploy's own statement of which jobs the demo runs, and a stale copy is
# a job list nobody wrote. The half an admin does tune - off / hourly / daily -
# lives in $WEBROOT/signbank_data/.settings.json and is never touched here.
sed "s|@WEBROOT@|$WEBROOT|g" config/pythoncron.demo.json > /tmp/pythoncron-config.json
scp -q /tmp/pythoncron-config.json "$HOST:/tmp/pythoncron-config.json"
rm -f /tmp/pythoncron-config.json
ssh "$HOST" "set -e
  sudo install -o root -g root -m 644 /tmp/pythoncron-config.json $PC_CONF/config.json
  rm -f /tmp/pythoncron-config.json
  sudo ln -sfn $PC_CONF/config.json $PC_HOME/config.json"
echo "  $PC_CONF/config.json installed ($(grep -c service_name config/pythoncron.demo.json) job), $PC_HOME/config.json -> it"

# --- 4. the unit --------------------------------------------------------
sed -e "s|@HOME@|$PC_HOME|g" -e "s|@STATE@|$PC_STATE|g" \
    -e "s|@CONFIG@|$PC_CONF/config.json|g" -e "s|@USER@|$SVCUSER|g" \
    -e "s|@WEBROOT@|$WEBROOT|g" \
    config/python-scheduler.service.template > /tmp/$UNIT
scp -q /tmp/$UNIT "$HOST:/tmp/$UNIT"; rm -f /tmp/$UNIT
ssh "$HOST" "set -e
  sudo install -o root -g root -m 644 /tmp/$UNIT /etc/systemd/system/$UNIT
  rm -f /tmp/$UNIT
  sudo systemctl daemon-reload
  sudo systemctl enable --quiet $UNIT
  sudo systemctl restart $UNIT"
echo "  $UNIT installed and restarted"

# --- 5. show what got registered ---------------------------------------
# Evidence rather than assertion, in the style of verify.sh: the config the
# scheduler validated, and whether the unit is actually up.
ssh "$HOST" "cd $PC_HOME && sudo -u $SVCUSER PYTHONCRON_STATE_DIR=$PC_STATE \
             /usr/bin/python3 scheduler_v2.py --config $PC_CONF/config.json --validate-config" \
  | sed 's/^/  /'
printf '  %-24s %s\n' "$UNIT" "$(ssh "$HOST" "systemctl is-active $UNIT")"
