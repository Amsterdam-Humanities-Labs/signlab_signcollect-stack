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
# The target hostname is NOT hardcoded - a redeploy onto a different VPS only
# needs a different DOMAIN. It ends up in cookie domains and redirect
# allow-lists in login.html / logout.html, so getting it wrong silently breaks
# sign-in.
#
# Usage: DOMAIN=demo2.example.org rewrite-urls.sh <tree> [<tree> ...]
set -euo pipefail

DOMAIN=${DOMAIN:-dev.taila8bdbd.ts.net}
[ $# -ge 1 ] || { echo "usage: [DOMAIN=host] $0 <tree> [<tree> ...]" >&2; exit 2; }
echo "target domain: $DOMAIN"

total=0
for tree in "$@"; do
  [ -d "$tree" ] || { echo "skip (not a directory): $tree" >&2; continue; }
  while IFS= read -r -d '' f; do
    grep -qE 'signcollect\.nl|@DOMAIN@' "$f" 2>/dev/null || continue
    before=$(grep -coE 'https?://[a-z.-]*signcollect\.nl' "$f" || true)
    DOMAIN="$DOMAIN" perl -pi -e '
      # 1. subdomains first - the bare-host rule below would eat their suffix.
      s{https?://api\.signcollect\.nl}{/api}g;
      s{https?://media\.signcollect\.nl}{/media}g;
      # The DocumentRoot of mocap.signcollect.nl is /web/mocap_site, and the demo
      # deploys that directory under the one origin - so the subdomain
      # becomes the path it already lives at. NOT /mocap: that path is the
      # separate signlab_mocap component, which mocapStudio fetches from.
      s{https?://mocap\.signcollect\.nl}{/mocap_site}g;
      # avatar.signcollect.nl is an Apache reverse proxy to a Vite dev server
      # on localhost:5173 over on production - a service, not a docroot, out of
      # scope like ISS_Server. Left to the bare-host rule it would become
      # "avatar.<DOMAIN>", a name that does not exist and whose failure looks
      # like a DNS fault; this makes it a plain 404 instead.
      s{https?://avatar\.signcollect\.nl}{/avatar-not-deployed}g;
      # 2. WebSockets -> loopback. ISS_Server is out of scope, so these must
      #    fail locally and fast rather than dial production.
      s{wss?://signcollect\.nl}{ws://127.0.0.1:9102}g;
      # 3. same-origin absolute -> relative.
      s{https?://signcollect\.nl}{}g;
      # 4. bare hostname last - cookie domains and redirect allow-lists in
      #    login.html / logout.html, which would silently break sign-in.
      s{(?<![/\w])\.?signcollect\.nl}{$ENV{DOMAIN}}g;
      # 5. explicit placeholder in the demo-only files. These have no
      #    signcollect.nl left to match on, so without this they would keep
      #    whichever host they were last rewritten for.
      s{\@DOMAIN\@}{$ENV{DOMAIN}}g;
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
