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
DRY=""
[ "${1:-}" = "--dry-run" ] && { DRY="--dry-run"; echo "(dry run - nothing is written)"; }
echo "target host: $HOST"

# .env holds the live DB credentials and is never shipped or deleted.
#
# api/ is the signlab_sCAPI submodule mounted at /api. It is a separate
# service, out of scope for an interface-only deploy, and clone.sh does not
# populate it - without this exclude, rsync --delete would replace the
# working API with an empty directory.
KEEP=(--exclude '.env' --exclude '.git' --exclude 'node_modules' --exclude 'api/')

echo "== git-backed components =="
while IFS=$'\t' read -r webdir repo branch; do
  case "$webdir" in ''|\#*) continue ;; esac
  [ -d "build/$repo" ] || { echo "  MISSING build/$repo - run scripts/clone.sh" >&2; exit 1; }
  rsync -a --delete $DRY "${KEEP[@]}" "build/$repo/" "$HOST:/web/$webdir/"
  printf '  %-24s -> /web/%s\n' "$repo" "$webdir"
done < scripts/repos.tsv

echo "== vendored components =="
# menu_old / nmm / downloadVideos are whole directories, safe to --delete.
for d in menu_old nmm downloadVideos; do
  rsync -a --delete $DRY "${KEEP[@]}" "web_extra/$d/" "$HOST:/web/$d/"
  printf '  %-24s -> /web/%s\n' "$d" "$d"
done
# Root files: no --delete, /web's root is shared with demo-only files.
rsync -a $DRY "${KEEP[@]}" --exclude '*/' web_extra/ "$HOST:/web/"
echo "  root files               -> /web/"

echo
echo "next: scripts/verify.sh https://<domain>"
