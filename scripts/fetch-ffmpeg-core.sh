#!/usr/bin/env bash
# Put ffmpeg.wasm's 32MB core next to each copy of the annotation editor.
#
# THIS SCRIPT RUNS ON THE DEMO HOST, from scripts/host-bootstrap.sh, after the
# components have been fetched and hard-reset.
#
# WHY THE FILE IS NOT IN GIT
#
# signlab_annotation-tool ships the editor three times - v3/, webcam/ and
# clusters/tool/ (v1/ and v2/ were removed as unlinked) - and each one loads
# its converter by a relative URL:
#
#   wasmURL: new URL('vendor/ffmpeg/esm/ffmpeg-core.wasm', document.baseURI)
#
# so each needs its own copy at its own path. Four of those copies used to be
# committed: 32,129,114 bytes each, 128MB of identical bytes, in a repository
# that is cloned onto every host and every workstation. The repo's .gitignore
# has named all five since the file was added; the four predate the rule.
#
# clusters/tool/ is the one that never was committed, and it is the pattern
# this follows: production serves its vendor/ffmpeg/ from files that live on
# the server and not in the repository. What production does NOT have is a
# script that puts them there, which is why clusters/tool/ has been shipping
# to the demo hosts with no converter at all since it was first deployed.
#
# WHY THIS IS SAFE ACROSS REDEPLOYS
#
# host-bootstrap.sh's per-component `git clean -fd` has no -x, so it spares
# anything the component gitignores - and signlab_annotation-tool ignores
# `vendor/` wholesale. So a file placed here survives every subsequent deploy
# untouched, and this script's own hash check makes the second run a no-op.
#
# WHY A DOWNLOAD AND NOT A COPY
#
# There is nothing on the host to copy it from. The deploy is a git clone and
# nothing else - no rsync, no workstation in the path - so the bytes have to
# come from somewhere on the network, and the two npm CDNs below are the
# upstream that produced them in the first place. The exact release is pinned
# and the download is rejected unless it hashes to the same 32MB that used to
# be committed, so "fetched from a CDN" is not a weaker guarantee than "read
# out of the repository": it is the same bytes or it is a failed deploy.
#
# The download happens once per host. It is cached outside the docroot, keyed
# by version, so re-running the install does not re-fetch it and a component
# reset does not lose it.
#
# Usage:  scripts/fetch-ffmpeg-core.sh <annotation-tool-directory>
set -euo pipefail

# @ffmpeg/core 0.12.6 - the version 814.ffmpeg.js in the repo names, and the
# exact blob that was committed under v1..v3 and webcam until it was removed.
CORE_VERSION=0.12.6
CORE_SHA256=2390efa7fb66e7e42dbae15427571a5ffc96b829480904c30f471f0a78967f61
CORE_URLS=(
  "https://cdn.jsdelivr.net/npm/@ffmpeg/core@$CORE_VERSION/dist/esm/ffmpeg-core.wasm"
  "https://unpkg.com/@ffmpeg/core@$CORE_VERSION/dist/esm/ffmpeg-core.wasm"
)

# Every directory that has its own index.html loading vendor/ffmpeg/… . Derived
# from the tree rather than hardcoded would be cleverer and worse: a typo in a
# glob would silently place nothing, and a missing converter is invisible until
# somebody drops a video in.
# webcam/ and clusters/tool/ became redirects to v3/?mode=... (signlab_annotation-tool#7).
EDITORS=(v3)

ROOT=${1:-}
[ -n "$ROOT" ] || { echo "usage: $0 <annotation-tool-directory>" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "not a directory: $ROOT" >&2; exit 2; }

sha256() { # sha256 <file> - Linux has sha256sum, macOS has shasum
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/signcollect-ffmpeg
CORE="$CACHE/ffmpeg-core-$CORE_VERSION.wasm"

if [ -f "$CORE" ] && [ "$(sha256 "$CORE")" = "$CORE_SHA256" ]; then
  echo "  cached   ffmpeg-core $CORE_VERSION  ($CORE)"
else
  mkdir -p "$CACHE"
  got=0
  for url in "${CORE_URLS[@]}"; do
    echo "  fetching ffmpeg-core $CORE_VERSION from ${url%%/npm/*}…"
    curl -fsSL --max-time 300 "$url" -o "$CORE.part" || continue
    if [ "$(sha256 "$CORE.part")" = "$CORE_SHA256" ]; then got=1; break; fi
    echo "  WRONG HASH from $url - discarded" >&2
  done
  if [ "$got" != 1 ]; then
    rm -f "$CORE.part"
    echo "could not fetch a verified @ffmpeg/core@$CORE_VERSION - the annotation" >&2
    echo "editor would load but fail on the first video conversion. Refusing to" >&2
    echo "pretend the deploy succeeded." >&2
    exit 1
  fi
  mv "$CORE.part" "$CORE"
fi

# The small loaders. They ARE tracked - only the 32MB core was ever the
# problem - so v3 always has them after the reset, and clusters/tool, whose
# whole vendor/ directory is untracked, is given a copy of them.
LOADERS=(ffmpeg.js util.js 814.ffmpeg.js esm/ffmpeg-core.js)
SRC="$ROOT/v3/vendor/ffmpeg"

for d in "${EDITORS[@]}"; do
  [ -d "$ROOT/$d" ] || { printf '  %-14s absent - skipped\n' "$d"; continue; }
  v="$ROOT/$d/vendor/ffmpeg"
  mkdir -p "$v/esm"
  placed=""
  for l in "${LOADERS[@]}"; do
    [ -f "$v/$l" ] && continue
    [ -f "$SRC/$l" ] || { echo "  missing loader $SRC/$l" >&2; exit 1; }
    cp -a "$SRC/$l" "$v/$l"; placed="$placed $l"
  done
  if [ -f "$v/esm/ffmpeg-core.wasm" ] && \
     [ "$(sha256 "$v/esm/ffmpeg-core.wasm")" = "$CORE_SHA256" ]; then
    printf '  %-14s core present%s\n' "$d" "${placed:+, placed$placed}"
  else
    cp "$CORE" "$v/esm/ffmpeg-core.wasm.part" && mv "$v/esm/ffmpeg-core.wasm.part" "$v/esm/ffmpeg-core.wasm"
    printf '  %-14s core placed%s\n' "$d" "${placed:+, placed$placed}"
  fi
done
