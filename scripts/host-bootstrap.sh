#!/usr/bin/env bash
# Build the docroot. THIS SCRIPT RUNS ON THE DEMO HOST, not on a workstation.
#
# It replaces scripts/clone.sh + scripts/deploy.sh, which cloned seventeen
# repositories onto a workstation, rewrote them there, and rsynced the result
# up. Three things were wrong with that:
#
#   - rsync. The new demo host does not have it and may not have it, so a
#     deploy that needs it cannot run at all.
#   - macOS is case-insensitive. signlab_hh tracks both
#     data/pages/vitamine-D.json and data/pages/vitamine-d.json (and the same
#     pair under backup/); a checkout on a Mac silently collapses each to one
#     file, so 7659 of 7661 files were ever deployed and nobody could see
#     which two were missing. Cloning on Linux is the fix, and it is a fix
#     that cannot regress.
#   - 500MB through the workstation on every deploy, and only the workstation
#     owner could deploy at all.
#
# So the host clones from GitHub itself. It can: scripts/host-auth.sh gives
# it a gh login and a git credential helper for the private org repos.
#
# WHY THE URL REWRITE MOVED HERE, WHICH IS THE WHOLE POINT
#
# The deployed tree is not the git tree. Production URLs are baked into the
# source - https://api.signcollect.nl, wss://signcollect.nl/... - and
# scripts/rewrite-urls.sh turns them into same-origin paths so the demo has
# no route back to production. That rewrite is the only reason a file copy
# existed between git and the docroot: a plain `git pull` on the host would
# serve production URLs, which is precisely what scripts/isolate.sh and
# scripts/verify.sh exist to prevent.
#
# The rewrite therefore runs here, on the host, between the clone and the
# first request. Each component's docroot directory IS its git checkout, and
# each deploy is:
#
#     fetch -> reset --hard -> clean -> rewrite-urls.sh -> purge-artifacts.sh
#
# reset --hard puts the pristine, production-URL tree on disk and the rewrite
# immediately replaces it, every run. That ordering is deliberate: the
# rewrite is not idempotent in the sense of being re-appliable to its own
# output (nothing matching signcollect.nl is left after the first pass), so
# re-deriving it from a known-clean tree is the only way a changed DOMAIN
# ever takes effect. It is also why the checkout is left permanently dirty
# and that is fine - nobody commits from a docroot.
#
# .git inside the docroot is safe here and was checked rather than assumed:
# apache/signcollect-web.conf already denies <DirectoryMatch "/\.(git|svn)">
# and any file beginning with a dot, server-wide.
#
# Usage (on the host):
#   DOMAIN=demo.example.org scripts/host-bootstrap.sh
#   WEBROOT=/srv/signcollect DOMAIN=... scripts/host-bootstrap.sh
set -euo pipefail

cd "$(dirname "$0")/.."
SRC=$(pwd)
WEBROOT=${WEBROOT:-/web}
DOMAIN=${DOMAIN:-}
ORG=${ORG:-Amsterdam-Humanities-Labs}
[ -n "$DOMAIN" ] || { echo "DOMAIN is not set - refusing to bake a wrong hostname into cookies" >&2; exit 2; }

command -v git >/dev/null || { echo "git is not installed on this host" >&2; exit 1; }
git ls-remote "https://github.com/$ORG/signlab_zin" >/dev/null 2>&1 || {
  echo "this host cannot read the private org repos - run scripts/host-auth.sh first" >&2; exit 1; }

echo "== components -> $WEBROOT (clone, rewrite, purge) =="
echo "   source: $SRC   domain: $DOMAIN"

# Untracked files that live inside a component directory and must survive a
# redeploy. `git clean` without -x already spares everything the component
# gitignores (vendor/, .env, signbank_sync/config.php, per-repo credential
# files), so this list is only for things no upstream .gitignore knows about.
#
# Patterns are gitignore-shaped and therefore match at any depth unless
# anchored - the same trap that made deploy.sh's unanchored `--exclude 'api/'`
# swallow signlab_viconDashboard/api and 404 every panel on the dashboard. So
# the one path-specific exclusion below is anchored, and applied only to the
# component it is about.
CLEAN_KEEP=(-e mysql_config.php -e .env -e .session_secret -e node_modules)

# /web/zin/api is the sCAPI service mounted at /api by
# apache/signcollect-mounts.conf. It is a separate deployment, not part of
# signlab_zin's tree, so an unguarded clean would delete a working API.
per_component_keep() {
  case "$1" in
    signlab_zin) printf '%s\n' "-e" "/api/" ;;
  esac
}

sync_repo() { # sync_repo <repo> <branch> <dir>
  local repo=$1 branch=$2 dir=$3 act url
  url="https://github.com/$ORG/$repo.git"
  if [ -e "$dir/.git" ]; then
    act=updated
  else
    # Decided before `git init`, which creates .git and would make every
    # directory look non-empty: a cold install reported seventeen components
    # "adopted", which is the word for taking over a tree that was already
    # there and exactly the wrong thing to tell somebody watching their first
    # install of a host that had nothing on it.
    if [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
      act=adopted
    else
      act=cloned
    fi
    # `git init` rather than `git clone`, because on a host that was
    # previously deployed by rsync the directory already exists and is full
    # of files, and clone refuses a non-empty target. init + fetch + reset
    # --hard adopts such a tree in place: reset overwrites the untracked
    # copies with the tracked originals, and the clean below removes
    # whatever the repository no longer has. That is the rsync --delete this
    # replaces, expressed in the only vocabulary the host now needs.
    mkdir -p "$dir"
    git -C "$dir" init --quiet
    git -C "$dir" remote add origin "$url"
  fi
  git -C "$dir" remote set-url origin "$url"
  # --depth 1: this is a deploy, not a working copy. History of
  # signlab_demo-media alone is not worth carrying, and nothing here ever
  # needs to look at a parent commit.
  git -C "$dir" fetch --quiet --depth 1 origin "$branch"
  git -C "$dir" reset --quiet --hard FETCH_HEAD
  git -C "$dir" checkout --quiet -B "$branch" FETCH_HEAD
  local keep; keep=$(per_component_keep "$repo")
  # shellcheck disable=SC2086
  git -C "$dir" clean --quiet -fd "${CLEAN_KEEP[@]}" $keep
  printf '  %-8s %-24s -> %-18s %s\n' \
    "$act" "$repo" "${dir#"$WEBROOT"/}" "$(git -C "$dir" rev-parse --short HEAD)"
}

composer_dirs=()
while IFS=$'\t' read -r webdir repo branch; do
  case "$webdir" in ''|\#*) continue ;; esac
  sync_repo "$repo" "$branch" "$WEBROOT/$webdir"
  [ -f "$WEBROOT/$webdir/composer.json" ] && composer_dirs+=("$webdir")
done < "$SRC/scripts/repos.tsv"

# The unversioned parts of production. They have no upstream repository of
# their own, so they are vendored in this deploy repo under web_extra/ and
# arrive on the host inside its checkout. Staged into a scratch tree before
# the rewrite, never rewritten in place: the rewrite substitutes DOMAIN, and
# doing that to the checkout would leave one host's name in a git working
# tree for the next deploy to inherit.
STAGE=${STAGE:-$HOME/.cache/signcollect-stage}
echo "== vendored components (web_extra/) =="
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -a "$SRC/web_extra/." "$STAGE/"

echo "== rewriting production URLs =="
# One pass over everything, components and vendored alike, so there is
# exactly one place where a production hostname can survive.
targets=("$STAGE")
while IFS=$'\t' read -r webdir repo branch; do
  case "$webdir" in ''|\#*) continue ;; esac
  targets+=("$WEBROOT/$webdir")
done < "$SRC/scripts/repos.tsv"
DOMAIN="$DOMAIN" "$SRC/scripts/rewrite-urls.sh" "${targets[@]}" | tail -1

echo "== purging artifacts =="
"$SRC/scripts/purge-artifacts.sh" "${targets[@]}" || true

# Placed after the rewrite, so what lands is what gets served.
#
# nmm/ and downloadVideos/ are whole directories this repo owns end to end,
# which is what makes the delete-then-copy safe: there is no per-host file
# inside either. zipFiles/ is the exception - downloadThemaVideo.php writes
# generated archives there as www-data - so it is re-created rather than
# resurrected, exactly as rsync --delete used to leave it.
echo "== placing vendored components =="
for d in nmm downloadVideos; do
  rm -rf "$WEBROOT/$d"
  cp -a "$STAGE/$d" "$WEBROOT/$d"
  printf '  %-24s -> %s/%s (%s files)\n' "$d" "$WEBROOT" "$d" \
    "$(find "$WEBROOT/$d" -type f | wc -l | tr -d ' ')"
done
[ -d "$WEBROOT/downloadVideos/zipFiles" ] || {
  mkdir -p "$WEBROOT/downloadVideos/zipFiles"; chmod 2777 "$WEBROOT/downloadVideos/zipFiles"; }

# Root files: copied, never deleted. The docroot root is shared with files
# that exist only on this host - mysql_config.php, .env, .session_secret,
# media_stub/ - so nothing here may sweep it.
n=0
for f in "$STAGE"/*; do
  [ -f "$f" ] || continue
  cp -a "$f" "$WEBROOT/"; n=$((n+1))
done
printf '  %-24s -> %s/ (%s files)\n' "root files" "$WEBROOT" "$n"

# Composer autoloaders. Today that is exactly one component: animMIDI (the
# repo is signlab_sC-Animation-PP). Its composer.json declares no packages -
# only PHP extensions, which provision.sh installs - but it declares a PSR-4
# map, App\ -> app/, and vendor/ is gitignored upstream. So a clone never
# carries an autoloader and the nine files under public/ that require it on
# their first line all 500.
#
# dump-autoload, not install: there is nothing to download, and a demo host
# must not need a package registry to come up. It runs here rather than in
# provision.sh because it is a function of the tree that was just placed,
# which at provision time does not exist yet.
if [ ${#composer_dirs[@]} -gt 0 ]; then
  echo "== composer autoloaders =="
  for d in "${composer_dirs[@]}"; do
    ( cd "$WEBROOT/$d" && composer dump-autoload --no-dev --optimize --no-interaction --quiet )
    printf '  %-24s -> %s/vendor/autoload.php\n' "$d" "$d"
  done
fi

# mocapStudio and animMIDI resolve mysql_config.php next to themselves rather
# than at the docroot, and it is gitignored upstream in each, so a clone never
# has it. Symlinked, not copied, so the host keeps exactly one credential
# file. Re-made every run: the clean above removes them (they are untracked
# and not ignored) and this puts them straight back.
for c in mocapStudio animMIDI; do
  [ -d "$WEBROOT/$c" ] || continue
  ln -sfn "$WEBROOT/mysql_config.php" "$WEBROOT/$c/mysql_config.php"
  printf '  %-24s -> %s/mysql_config.php\n' "$c/mysql_config.php" "$WEBROOT"
done

echo "== docroot built =="
