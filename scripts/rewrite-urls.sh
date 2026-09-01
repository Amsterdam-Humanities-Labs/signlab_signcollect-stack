#!/usr/bin/env bash
# Rewrite hardcoded production URLs so the deployed copy is same-origin and has
# no path back to signcollect.nl.
#
# Order matters: the bare host runs LAST, otherwise it would eat the
# "signcollect.nl" inside "api.signcollect.nl" and leave a broken "api." prefix.
#
# Rewritten:  .php .html .js .css .json .py .sh  - code and data the app reads.
# Left alone: .log .md .swift - committed test output, docs, and iOS client
#             code. None are executed here; the egress block covers them.
#
# Usage: rewrite-urls.sh <tree> [<tree> ...]
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: $0 <tree> [<tree> ...]" >&2; exit 2; }

total=0
for tree in "$@"; do
  [ -d "$tree" ] || { echo "skip (not a directory): $tree" >&2; continue; }
  while IFS= read -r -d '' f; do
    grep -q 'signcollect\.nl' "$f" 2>/dev/null || continue
    before=$(grep -coE 'https?://[a-z.-]*signcollect\.nl' "$f" || true)
    perl -pi -e '
      # 1. subdomains first - the bare-host rule below would eat their suffix.
      s{https?://api\.signcollect\.nl}{/api}g;
      s{https?://media\.signcollect\.nl}{/media}g;
      s{https?://mocap\.signcollect\.nl}{/mocap-removed}g;
      # 2. WebSockets -> loopback. ISS_Server is out of scope, so these must
      #    fail locally and fast rather than dial production.
      s{wss?://signcollect\.nl}{ws://127.0.0.1:9102}g;
      # 3. same-origin absolute -> relative.
      s{https?://signcollect\.nl}{}g;
      # 4. bare hostname last - cookie domains and redirect allow-lists in
      #    login.html / logout.html, which would silently break sign-in.
      s{(?<![/\w])\.?signcollect\.nl}{dev.taila8bdbd.ts.net}g;
    ' "$f"
    after=$(grep -coE 'https?://[a-z.-]*signcollect\.nl' "$f" 2>/dev/null || true)
    total=$(( total + before - after ))
    [ "$before" -gt 0 ] && printf '  %-64s %5s -> %s\n' "${f#./}" "$before" "$after"
  done < <(find "$tree" \
             \( -name node_modules -o -name .git \) -prune -o \
             -type f \( -name '*.js' -o -name '*.php' -o -name '*.html' \
                        -o -name '*.css' -o -name '*.json' -o -name '*.py' \
                        -o -name '*.sh' \) -print0)
done
echo "rewritten references: $total"
