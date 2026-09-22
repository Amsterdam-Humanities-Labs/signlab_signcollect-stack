#!/usr/bin/env bash
# Remove test artefacts and caches that must not reach a web server.
#
# cookies.txt in signlab_sCAPI carries a real PHPSESSID for api.signcollect.nl.
# The rest are committed test output and response captures - inert, but they
# sit inside the docroot and serve no purpose in a demo.
#
# -exec rm, not -delete: -delete implies -depth, which cancels -prune, and GNU
# find refuses that combination outright - it printed a warning and deleted
# nothing, and the caller's `|| true` hid it.
set -euo pipefail
[ $# -ge 1 ] || { echo "usage: $0 <tree> [<tree> ...]" >&2; exit 2; }
for tree in "$@"; do
  [ -d "$tree" ] || continue
  find "$tree" \( -name node_modules -o -name .git \) -prune -o -type f \( \
      -name 'cookies.txt' \
      -o -name 'test_*.log' -o -name 'test_complete*.log' \
      -o -name 'failed.json' -o -name 'user_simulation_results.json' \
      -o -name 'doen_api_response.json' \
    \) -print -exec rm -f {} +
done
