#!/usr/bin/env bash
# Install the per-host config files that are gitignored upstream and so never
# arrive with a clone.
#
# Runs AFTER scripts/host-bootstrap.sh, because these live inside deployed
# component directories - and because that script's `git clean` removes any
# of them that upstream does not gitignore, so the order is load-bearing, not
# merely conventional. Never overwrites an existing file: a host that already
# has a real config keeps it.
#
# The two files it installs are read out of the host's own checkout of this
# repo ($SRCDIR, put there by scripts/host-src.sh) rather than pushed from
# here. That is not tidiness - assets/glosses_transformed.json is 11MB, and
# it was the last thing in this script that a workstation had to carry.
#
# Usage: scripts/host-config.sh --host gomer@demo1
set -euo pipefail

cd "$(dirname "$0")/.."
SC_USAGE='usage: scripts/host-config.sh --host <ssh-target>'
# shellcheck source=scripts/_common.sh
. scripts/_common.sh
sc_parse_common "$@"
sc_require_host
sc_on_error "scripts/host-config.sh $(sc_retry_args)"
sc_doing "installing the per-host config files" \
  "These live inside deployed component directories, so host-bootstrap.sh must have run first.
     If $WEBROOT/menu_beta does not exist, that is the step that failed."

# A Signbank API key can be supplied for this host, and never through a
# tracked file. Two ways, both outside git:
#
#   SIGNBANK_API_KEY=... scripts/host-config.sh
#   echo 'SIGNBANK_API_KEY=...' >> secrets.env      (secrets.env is gitignored)
#
# Without one the demo still deploys: the connector page reports "geen
# sleutel" and an admin can paste one in. The key is written to the host once
# and never read back out of it by this script.
if [ -f secrets.env ]; then
  # shellcheck disable=SC1091
  . ./secrets.env
fi
SIGNBANK_API_KEY=${SIGNBANK_API_KEY:-}

# signbank_sync/config.php - php_api/current_user.php calls signbank_config()
# on every page load, and it throws when the file is missing, which surfaces
# in the UI as "Init failed: Internal Server Error".
#
# An existing file is normally left alone, because it may be a real config
# this script has no business rewriting. The one exception is the previous
# demo template, which pointed base_url at the discard port (127.0.0.1:9) so
# nothing could reach Signbank. That is not a config anyone would want to
# keep now that the connector exists, and it is recognisable with certainty,
# so it is replaced.
# The pattern matches the setting, not the word: this file's own comments
# mention the discard port, and matching those would reinstall on every run.
#
# The second replace-trigger is a state_dir that names some other install
# root. That is our own template rendered for a different --webroot, and it is
# recognisable with the same certainty as the discard port: the file still
# carries this repo's DEMO-instance header, and its state_dir is not the one
# this host is being installed with. Left alone, the connector writes its key,
# its lock, its schedule and its 11MB dump to a directory outside the docroot
# and reports "cannot create /web/signbank_data" for every one of them, on a
# host where every page otherwise serves. A real config an admin wrote does
# not carry that header and is not touched.
if ssh "$HOST" "test -f $WEBROOT/menu_beta/signbank_sync/config.php &&
                ! grep -q \"'base_url'.*127\\.0\\.0\\.1:9\" $WEBROOT/menu_beta/signbank_sync/config.php &&
                ! { grep -q 'DEMO instance' $WEBROOT/menu_beta/signbank_sync/config.php &&
                    ! grep -qF \"'state_dir'        => '$WEBROOT/signbank_data'\" $WEBROOT/menu_beta/signbank_sync/config.php; }"; then
  echo "  signbank_sync/config.php already present - left alone"
else
  ssh "$HOST" "mkdir -p $WEBROOT/menu_beta/signbank_sync &&
               sed 's|@WEBROOT@|$WEBROOT|g' $SRCDIR/config/signbank_sync.demo.php \
                 > $WEBROOT/menu_beta/signbank_sync/config.php &&
               sudo chown \"\$USER\":www-data $WEBROOT/menu_beta/signbank_sync/config.php &&
               chmod 640 $WEBROOT/menu_beta/signbank_sync/config.php"
  echo "  signbank_sync/config.php installed (demo values, state_dir $WEBROOT/signbank_data)"
fi

# $WEBROOT/signbank_data - everything the Signbank connector owns and writes: the
# runtime API key, the refresh schedule and state, and the gloss dump itself.
#
# It exists because $WEBROOT is gomer:staff 755 and the web server is www-data:
# rewriting the dump atomically means renaming a temp file over it, and
# rename(2) needs write permission on the *directory*. Making $WEBROOT itself
# writable by www-data would let any PHP bug drop a file at the docroot root,
# so instead one directory is www-data's and $WEBROOT/glosses_transformed.json is
# a symlink into it (apache has +FollowSymLinks on $WEBROOT).
#
# Two users write here: www-data, for the "refresh now" button, and the
# deploy user, for the scheduled job pythonCron runs. Either may have to
# replace a file the other wrote - the lock, the state, the dump - so the
# directory is setgid www-data and everything in it is group-writable, and
# the deploy user joins that group. Group membership rather than a 0777
# directory: the files stay unwritable by anyone else.
ssh "$HOST" "export WEBROOT='$WEBROOT'; "'set -e
  sudo install -d -o www-data -g www-data -m 2775 $WEBROOT/signbank_data
  sudo chgrp -R www-data $WEBROOT/signbank_data
  sudo chmod -R g+rwX  $WEBROOT/signbank_data
  id -nG "$USER" | tr " " "\n" | grep -qx www-data || sudo usermod -aG www-data "$USER"'
echo "  $WEBROOT/signbank_data ready (www-data:www-data 2775, $HOST deploy user in group www-data)"

# annotation-tool's cluster corrections, kept outside its checkout so a
# redeploy cannot revert them. io.php seeds the contents on first use; it only
# needs a directory the web server may write. host-bootstrap.sh moves any
# copies still at the old in-checkout path here before its reset.
ssh "$HOST" "export WEBROOT='$WEBROOT'; "'sudo install -d -o www-data -g www-data -m 2775 $WEBROOT/annotation_data/clusters'
echo "  $WEBROOT/annotation_data/clusters ready (www-data:www-data 2775)"
ssh "$HOST" "export WEBROOT='$WEBROOT'; "'sudo install -d -o www-data -g www-data -m 2775 $WEBROOT/videofix_data'
echo "  $WEBROOT/videofix_data ready (www-data:www-data 2775)"

# Group membership is read at login, so the usermod above reaches the
# scheduled job (systemd starts it with a fresh group list) but not this run.
# Over ssh every call is a new login and that difference never showed; under
# --local the whole install is one process, still without www-data, and a
# plain `cp` into the directory fails with "Permission denied" - on every
# retry from the same terminal, too. So everything below that writes into
# signbank_data goes through sudo and sets the owner itself, rather than
# relying on a group this process may not have yet.

# The gloss dump itself. It used to sit at the docroot root and every
# consumer read it there; it now lives in the connector's directory, which is
# the only place the web server can replace it atomically. Each consumer has
# been repointed at $WEBROOT/signbank_data/glosses_transformed.json (the browser
# ones at /signbank_data/...), so nothing is left resolving the old path and
# $WEBROOT/glosses_transformed.json is removed rather than symlinked - a link
# would keep a missed consumer working silently and hide that it was missed.
#
# A regular file still at the old path is moved, never deleted: on a host
# that has not been migrated it is the only copy, and on a host that has
# refreshed it, it is newer than the vendored seed. That is also why the seed
# from assets/ is no longer copied unconditionally - a deploy must not
# overwrite a fresh dump with a stale one.
ssh "$HOST" "export WEBROOT='$WEBROOT'; "'set -e
  if [ -L $WEBROOT/glosses_transformed.json ]; then
    rm -f $WEBROOT/glosses_transformed.json
  elif [ -f $WEBROOT/glosses_transformed.json ]; then
    if [ ! -f $WEBROOT/signbank_data/glosses_transformed.json ]; then
      sudo mv $WEBROOT/glosses_transformed.json $WEBROOT/signbank_data/glosses_transformed.json
      sudo chown www-data:www-data $WEBROOT/signbank_data/glosses_transformed.json
    else
      rm -f $WEBROOT/glosses_transformed.json
    fi
  fi'
if ssh "$HOST" "export WEBROOT='$WEBROOT'; "'test -s $WEBROOT/signbank_data/glosses_transformed.json'; then
  echo "  glosses_transformed.json present ($(ssh "$HOST" "export WEBROOT='$WEBROOT'; "'stat -c %s $WEBROOT/signbank_data/glosses_transformed.json') bytes) in $WEBROOT/signbank_data"
else
  ssh "$HOST" "sudo install -o www-data -g www-data -m 664 $SRCDIR/assets/glosses_transformed.json $WEBROOT/signbank_data/glosses_transformed.json"
  echo "  glosses_transformed.json seeded from the host's own assets/ ($(ssh "$HOST" "export WEBROOT='$WEBROOT'; "'stat -c %s $WEBROOT/signbank_data/glosses_transformed.json') bytes)"
fi
ssh "$HOST" "export WEBROOT='$WEBROOT'; "'sudo chmod 664 $WEBROOT/signbank_data/glosses_transformed.json 2>/dev/null || true'

# The API key. A key already on the host is left alone - it may have been
# replaced by an admin on the connector page, and this script must not
# silently roll that back.
if ssh "$HOST" "export WEBROOT='$WEBROOT'; "'test -s $WEBROOT/signbank_data/.signbank_key'; then
  echo "  signbank API key already present - left alone"
elif [ -n "$SIGNBANK_API_KEY" ]; then
  # Piped over stdin, so the key never appears in a command line or in the
  # remote shell's history.
  printf '%s\n' "$SIGNBANK_API_KEY" |
    ssh "$HOST" "export WEBROOT='$WEBROOT'; "'sudo install -o www-data -g www-data -m 640 /dev/stdin $WEBROOT/signbank_data/.signbank_key'
  echo "  signbank API key installed (value not shown)"
else
  echo "  no SIGNBANK_API_KEY given - connector will report 'geen sleutel' until an admin sets one"
fi

# $WEBROOT/.session_secret - signs the session cookie. Without it session.php
# falls back to accepting an unsigned cookie, which is what let a hand-written
# {"userId":38} impersonate that user. Generated once and never rotated here:
# rotating it logs everyone out.
if ssh "$HOST" "export WEBROOT='$WEBROOT'; "'test -s $WEBROOT/.session_secret'; then
  echo "  .session_secret already present - left alone"
else
  ssh "$HOST" "export WEBROOT='$WEBROOT'; "'umask 027 && openssl rand -hex 32 > $WEBROOT/.session_secret &&
               sudo chown "$USER":www-data $WEBROOT/.session_secret &&
               chmod 640 $WEBROOT/.session_secret'
  echo "  .session_secret generated (value not shown)"
fi


# SC_UPLOAD_TOKEN - the shared token machine clients (capture-machine curl,
# the OBS uploader) send as X-Api-Token to mocap/uploadOBS.php and
# mocapDataPackage/upload.php. Those endpoints refuse everything when it is
# unset, so a demo gets a random one, once, in the env file sc_env() reads.
if ssh "$HOST" "export WEBROOT='$WEBROOT'; "'grep -q "^SC_UPLOAD_TOKEN=" $WEBROOT/.env'; then
  echo "  SC_UPLOAD_TOKEN already in .env - left alone"
else
  ssh "$HOST" "export WEBROOT='$WEBROOT'; "'printf "SC_UPLOAD_TOKEN=%s\n" "$(openssl rand -hex 24)" >> $WEBROOT/.env'
  echo "  SC_UPLOAD_TOKEN generated in .env (value not shown)"
fi
