#!/usr/bin/env bash
# Push the built tree to a demo host's /web.
#
# Deploys per-component rather than syncing /web as one tree, because /web
# also holds files that exist only on the demo host and must survive a
# redeploy:
#
#   mysql_config.php  demo database credentials (never in git)
#   media_stub/       stands in for media.signcollect.nl
#
# So --delete is scoped to each component directory, and credential files are
# excluded so a component's --delete cannot take them out.
#
# Runs AFTER clone.sh + rewrite-urls.sh.
#
# Usage: HOST=demovps scripts/deploy.sh [--dry-run]
set -euo pipefail

cd "$(dirname "$0")/.."
HOST=${HOST:-demovps}
# The docroot on the target. Everything below builds its paths from this
# rather than repeating /web, because moving the docroot is a change the
# demo expects to make.
WEBROOT=${WEBROOT:-/web}
DRY=""
[ "${1:-}" = "--dry-run" ] && { DRY="--dry-run"; echo "(dry run - nothing is written)"; }
echo "target host: $HOST"

# .env holds the live DB credentials and is never shipped or deleted.
#
# api/ is the signlab_sCAPI submodule mounted at /api. It is a separate
# service, out of scope for an interface-only deploy, and clone.sh does not
# populate it - without this exclude, rsync --delete would replace the
# working API with an empty directory.
# signbank_sync/config.php is gitignored upstream and written per host by
# host-config.sh. Without this exclude, --delete removes it and every page
# load 500s in php_api/current_user.php.
KEEP=(--exclude '.env' --exclude '.git' --exclude 'node_modules' \
      --exclude 'signbank_sync/config.php')

# api/ is excluded for signlab_zin ONLY - it is the signlab_sCAPI submodule
# mounted at /api, which clone.sh does not populate, so an unguarded --delete
# would replace a working API with an empty directory.
#
# It must be anchored to the transfer root. An unanchored 'api/' matches at
# every depth, which silently stopped signlab_viconDashboard/api/ from ever
# deploying: the dashboard rendered and every panel 404'd.
per_component_excludes() {
  case "$1" in
    signlab_zin) printf '%s\n' "--exclude=/api/" ;;
  esac
}

echo "== git-backed components =="
while IFS=$'\t' read -r webdir repo branch; do
  case "$webdir" in ''|\#*) continue ;; esac
  [ -d "build/$repo" ] || { echo "  MISSING build/$repo - run scripts/clone.sh" >&2; exit 1; }
  rsync -a --delete $DRY "${KEEP[@]}" "build/$repo/" "$HOST:$WEBROOT/$webdir/"
  printf '  %-24s -> %s/%s\n' "$repo" "$WEBROOT" "$webdir"
done < scripts/repos.tsv

# Composer autoloaders, for the components that have a composer.json.
#
# Today that is exactly one: animMIDI (the repo is signlab_sC-Animation-PP).
# Its composer.json declares no packages at all - only PHP extensions, which
# provision.sh installs - but it declares a PSR-4 map, App\ -> app/, and
# vendor/ is gitignored upstream. So a clone never carries an autoloader, and
# the nine files under public/ that `require dirname(__DIR__).'/vendor/autoload.php'`
# on their first line all 500. `composer dump-autoload` is the whole fix.
#
# This runs here, in deploy.sh, rather than in provision.sh or install.sh, for
# three reasons that all point the same way:
#
#   - It is this script's own damage to repair. The rsync above is
#     --delete, so any vendor/ the host had is removed moments before the
#     component lands. Cause and cure a few lines apart is easier to keep
#     true than cause here and cure in the caller.
#   - The autoloader is a function of the tree that was just shipped - a
#     classmap of app/ - so it cannot be built before the files exist.
#     provision.sh runs before any code is on the host at all.
#   - `scripts/deploy.sh` is documented as runnable on its own. If the step
#     lived in install.sh, a plain deploy would leave animMIDI 500ing, which
#     is precisely the state this is fixing.
#
# Excluding vendor/ from the rsync instead was the obvious alternative and is
# wrong: signlab_annotation-tool has 20 vendor/ files tracked in git, so a
# blanket exclude would mean a fresh host never receives them.
#
# dump-autoload, not install - there is nothing to download, and a demo host
# must not need network access to a package registry to come up. -o builds a
# classmap so the PSR-4 lookup is not a filesystem scan per class; --no-dev
# drops the Tests\ entry, which is not shipped.
composer_dirs=()
while IFS=$'\t' read -r webdir repo branch; do
  case "$webdir" in ''|\#*) continue ;; esac
  [ -f "build/$repo/composer.json" ] && composer_dirs+=("$webdir")
done < scripts/repos.tsv
if [ ${#composer_dirs[@]} -gt 0 ]; then
  echo "== composer autoloaders =="
  if [ -n "$DRY" ]; then
    printf '  (dry run) would dump-autoload: %s\n' "${composer_dirs[*]}"
  else
    ssh "$HOST" "set -e
      for d in ${composer_dirs[*]}; do
        cd '$WEBROOT'/\$d
        composer dump-autoload --no-dev --optimize --no-interaction --quiet
        printf '  %-24s -> %s/vendor/autoload.php\n' \"\$d\" \"\$d\"
      done"
  fi
fi

echo "== vendored components =="
# nmm / downloadVideos are whole directories, safe to --delete.
for d in nmm downloadVideos; do
  rsync -a --delete $DRY "${KEEP[@]}" "build/web_extra/$d/" "$HOST:$WEBROOT/$d/"
  printf '  %-24s -> %s/%s\n' "$d" "$WEBROOT" "$d"
done
# Root files: no --delete, /web's root is shared with demo-only files.
rsync -a $DRY "${KEEP[@]}" --exclude '*/' build/web_extra/ "$HOST:$WEBROOT/"
echo "  root files               -> $WEBROOT/"

echo
echo "next: scripts/verify.sh https://<domain>"
