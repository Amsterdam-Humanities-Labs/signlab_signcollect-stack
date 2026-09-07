#!/usr/bin/env bash
# Obtain every git-backed component of the SignCollect interface into build/.
#
# GitHub is the only source. The unversioned parts of production (menu_old,
# nmm, downloadVideos, and the loose root .html files) are vendored in this
# repo under web_extra/ - they have no upstream repo of their own, so without
# vendoring a fresh checkout could not redeploy. Splitting them into real
# repos is tracked in the stack issue tracker.
#
# Nothing here touches signcollect.nl. That matters: the demo host is
# firewalled from production (scripts/isolate.sh), and a deploy that needed
# production access could never run from anywhere but this workstation.
#
# Usage: scripts/clone.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ORG=Amsterdam-Humanities-Labs

echo "== git-backed components =="
while IFS=$'\t' read -r webdir repo branch; do
  case "$webdir" in ''|\#*) continue ;; esac
  if [ -d "build/$repo/.git" ]; then
    git -C "build/$repo" fetch --quiet origin "$branch"
    git -C "build/$repo" checkout --quiet "$branch"
    git -C "build/$repo" reset --hard --quiet "origin/$branch"
    act=updated
  else
    gh repo clone "$ORG/$repo" "build/$repo" -- --branch "$branch" --quiet
    act=cloned
  fi
  printf '  %-8s %-24s -> /web/%-16s %s\n' \
    "$act" "$repo" "$webdir" "$(git -C "build/$repo" rev-parse --short HEAD)"
done < scripts/repos.tsv

echo "== vendored components (web_extra/, tracked in this repo) =="
for d in menu_old nmm downloadVideos; do
  printf '  %-16s %s files\n' "$d" "$(find "web_extra/$d" -type f | wc -l | tr -d ' ')"
done
printf '  %-16s %s\n' "root files" "$(ls web_extra/*.html web_extra/*.php web_extra/*.js 2>/dev/null | wc -l | tr -d ' ')"

echo
echo "next: DOMAIN=<host> scripts/rewrite-urls.sh build/*/ web_extra/ && HOST=<ssh> scripts/deploy.sh"
