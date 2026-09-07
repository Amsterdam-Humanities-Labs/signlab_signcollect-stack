#!/usr/bin/env bash
# Put this deploy repo on the demo host, so the host can build itself.
#
# The host needs more than the seventeen component repositories: it needs
# scripts/ (rewrite-urls.sh above all), web_extra/, assets/, db/, config/ and
# apache/. Those live here, and this repo has no remote of its own - its
# content is mirrored to GitHub as interface_deploy/ inside
# Amsterdam-Humanities-Labs/signlab_signcollect-stack by `git subtree`.
#
# So the host clones that stack repository. That is the permanent shape: a
# host with a gh login can fetch everything it needs without a workstation in
# the picture at all, which is the point of the whole rewrite.
#
# THE OVERLAY, AND WHY IT IS HERE
#
# The subtree mirror is pushed by hand, so between a commit here and that
# push the mirror is behind. `scripts/install.sh` has to mean "deploy the
# tree in front of me" - an operator who has just edited rewrite-urls.sh and
# runs install.sh must get that edit, not the last thing somebody mirrored -
# so after the clone this overlays the local HEAD tree onto the host's
# checkout.
#
# It is `git archive | tar`, not rsync: about a megabyte over the wire, of
# which all but a few kilobytes is assets/glosses_transformed.json. That is
# not the 500MB the old deploy pushed, and it is not a file the host could
# get any other way today. When the mirror is current the overlay writes the
# identical bytes and changes nothing; SKIP_OVERLAY=1 turns it off.
#
# Only tracked content is sent - `git archive HEAD` - so build/, secrets.env
# and .dbpass.local cannot leak onto a host by accident.
#
# Usage: scripts/host-src.sh --host gomer@demo1
set -euo pipefail

cd "$(dirname "$0")/.."
SC_USAGE='usage: scripts/host-src.sh --host <ssh-target>

  --host <target>   ssh target for the demo host (or set HOST)

Clones Amsterdam-Humanities-Labs/signlab_signcollect-stack onto the host and
overlays this working tree onto its interface_deploy/ directory.

  SRCROOT       where the checkout lands on the host (default ~/signcollect-deploy)
  SKIP_OVERLAY  set to 1 to use the mirror as-is, without the local overlay'
# shellcheck source=scripts/_common.sh
. scripts/_common.sh
sc_parse_common "$@"
sc_require_host

STACK_REPO=${STACK_REPO:-Amsterdam-Humanities-Labs/signlab_signcollect-stack}

echo "== deploy source on $HOST =="

# gh, not git, so the private-repo credential host-auth.sh installed is used
# the same way every other clone here uses it.
ssh "$HOST" "set -e
  d=$SRCROOT
  if [ -d \"\$d/.git\" ]; then
    git -C \"\$d\" fetch --quiet origin
    git -C \"\$d\" reset --quiet --hard origin/HEAD 2>/dev/null ||
      git -C \"\$d\" reset --quiet --hard \"origin/\$(git -C \"\$d\" rev-parse --abbrev-ref HEAD)\"
    echo \"  updated  $STACK_REPO -> \$d (\$(git -C \"\$d\" rev-parse --short HEAD))\"
  else
    rm -rf \"\$d\"
    gh repo clone $STACK_REPO \"\$d\" -- --depth 1 --quiet
    echo \"  cloned   $STACK_REPO -> \$d (\$(git -C \"\$d\" rev-parse --short HEAD))\"
  fi
  test -d \"\$d/interface_deploy\" || { echo '  no interface_deploy/ in the stack repo' >&2; exit 1; }"

if [ "${SKIP_OVERLAY:-}" = "1" ]; then
  echo "  overlay skipped (SKIP_OVERLAY=1) - the host runs the mirrored tree"
else
  bytes=$(git archive HEAD | wc -c | tr -d ' ')
  git archive --format=tar HEAD | gzip -9 |
    ssh "$HOST" "tar xzf - -C $SRCDIR"
  ssh "$HOST" "chmod +x $SRCDIR/scripts/*.sh $SRCDIR/tests/*.sh 2>/dev/null || true"
  echo "  overlaid this working tree ($(git rev-parse --short HEAD), $bytes bytes uncompressed)"
fi
