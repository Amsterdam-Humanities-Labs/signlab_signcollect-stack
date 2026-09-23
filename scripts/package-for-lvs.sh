#!/usr/bin/env bash
# Package files from a git repo's history for upload to UvA LVS (Large Volume
# Storage). See docs/data-storage.md. It uploads nothing: whoever has LVS
# access uploads the .tar.gz.
#
#   scripts/package-for-lvs.sh [-r REF] [-n NAME] [-o OUTDIR] SOURCE PATH...
#
#   SOURCE  a local clone, a .bundle file, or a clone URL
#   REF     commit or branch to read PATHs from (default HEAD). For files that
#           were deleted, use the parent of the deleting commit, e.g. c84c448^
#   PATH    files or directories as they were at REF
#
# Output in OUTDIR (default ./lvs-out):
#   NAME-DATE/MANIFEST.tsv   path, size, sha256, source commit (one line per file)
#   NAME-DATE/README.md      stub: fill in owner, sensitivity, retention
#   NAME-DATE.tar.gz         the files under NAME-DATE/, plus the two above
#
# Files go from git straight into the tar, never through the local disk:
# on macOS's case-insensitive disk, pairs like vitamine-D.json/vitamine-d.json
# would overwrite each other. Extract on a case-sensitive file system.
#
# Example (signlab_patient-info pipeline output, from the 2026-09-22 backup bundle):
#   scripts/package-for-lvs.sh -r c84c448^ -n signlab_hh-data \
#     ~/signlab-history-backups/signlab_hh-2026-09-22.bundle data
set -euo pipefail

ref=HEAD name='' out=./lvs-out
usage() { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
while getopts r:n:o:h opt; do
  case "$opt" in
    r) ref=$OPTARG ;; n) name=$OPTARG ;; o) out=$OPTARG ;;
    h) usage 0 ;; *) usage 2 >&2 ;;
  esac
done
shift $((OPTIND - 1))
[ $# -ge 2 ] || usage 2 >&2
src=$1; shift

if command -v sha256sum >/dev/null; then sha() { sha256sum | cut -d' ' -f1; }
else sha() { shasum -a 256 | cut -d' ' -f1; }; fi

# A bundle or URL is cloned into a temp mirror; a local clone is read in place.
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
if [ -d "$src" ] && git -C "$src" rev-parse --git-dir >/dev/null 2>&1; then
  repo=$src
  origin=$(git -C "$src" remote get-url origin 2>/dev/null || echo "$src")
else
  git clone -q --mirror "$src" "$tmp/src.git"
  repo=$tmp/src.git origin=$src
fi
g() { git -C "$repo" "$@"; }

commit=$(g rev-parse --verify -q "$ref^{commit}") || { echo "no such ref: $ref" >&2; exit 1; }
for p in "$@"; do
  if [ -z "$(g ls-tree --name-only "$commit" -- "$p")" ]; then
    echo "not at $ref: $p" >&2
    del=$(g log --all -1 --format=%h --diff-filter=D -- "$p" "$p/*" || true)
    [ -n "$del" ] && echo "  it was deleted in $del; try -r $del^" >&2
    exit 1
  fi
done

[ -n "$name" ] || name=$(basename "${origin%.git}" | sed 's/-[0-9-]*\.bundle$//; s/\.bundle$//')
dir=$name-$(date +%F)
mkdir -p "$out"
out=$(cd "$out" && pwd)
[ ! -e "$out/$dir" ] && [ ! -e "$out/$dir.tar.gz" ] || { echo "$out/$dir exists; remove it first" >&2; exit 1; }
mkdir "$out/$dir"

# MANIFEST: one line per file. Identical blobs are hashed once.
# (Plain files, not bash 4 arrays: macOS ships bash 3.2.)
g ls-tree -r -l -z "$commit" -- "$@" | tr '\0' '\n' \
  | awk -F'\t' '{ split($1, m, " "); if (m[2] == "blob") print m[3] "\t" m[4] "\t" $2 }' \
  > "$tmp/tree"                                     # blob, size, path
cut -f1 "$tmp/tree" | sort -u | while read -r blob; do
  printf '%s\t%s\n' "$blob" "$(g cat-file blob "$blob" | sha)"
done > "$tmp/hashes"                                # blob, sha256
man=$out/$dir/MANIFEST.tsv
printf 'path\tsize\tsha256\tcommit\n' > "$man"
awk -F'\t' -v c="$commit" 'NR == FNR { h[$1] = $2; next }
  { print $3 "\t" $2 "\t" h[$1] "\t" c }' "$tmp/hashes" "$tmp/tree" >> "$man"
files=$(wc -l < "$tmp/tree" | tr -d ' ')
bytes=$(awk -F'\t' '{ s += $2 } END { printf "%d", s }' "$tmp/tree")

# Paths that differ only in case: warn, since they collide on macOS/Windows.
clash=$(tail -n +2 "$man" | cut -f1 | tr '[:upper:]' '[:lower:]' | sort | uniq -d)

cat > "$out/$dir/README.md" <<EOF
# $dir

Packaged for UvA LVS on $(date +%F) with \`scripts/package-for-lvs.sh\`
from [signlab_signcollect-stack](https://github.com/Amsterdam-Humanities-Labs/signlab_signcollect-stack).

| | |
|---|---|
| Source | \`$origin\` |
| Commit | \`$commit\` (ref \`$ref\`) |
| Paths | $(printf '`%s` ' "$@") |
| Files | $files |
| Size | $bytes bytes (uncompressed) |
| What it is | TODO |
| Personal data | TODO: none / pseudonymous / identifiable |
| Owner | TODO: confirm |
| Retention | TODO |

\`MANIFEST.tsv\` lists every file: path, size in bytes, sha256, source commit.
Check a file with \`sha256sum <path>\` against its line.
$( [ -n "$clash" ] && printf '\nSome paths differ only in case. Extract on a case-sensitive file system:\n\n%s\n' "$(sed 's/^/- `/; s/$/`/' <<<"$clash")" )
EOF

# Tar: the files straight from git, then MANIFEST and README appended.
g archive --format=tar --prefix="$dir/" -o "$tmp/$dir.tar" "$commit" -- "$@"
(cd "$out" && tar -rf "$tmp/$dir.tar" "$dir/MANIFEST.tsv" "$dir/README.md")
gzip -n -c "$tmp/$dir.tar" > "$out/$dir.tar.gz"

echo "files:    $files ($bytes bytes)"
echo "manifest: $out/$dir/MANIFEST.tsv ($(($(wc -l < "$man") - 1)) lines + header)"
echo "tarball:  $out/$dir.tar.gz ($(wc -c < "$out/$dir.tar.gz" | tr -d ' ') bytes, sha256 $(sha < "$out/$dir.tar.gz"))"
[ -z "$clash" ] || echo "warning: $(wc -l <<<"$clash" | tr -d ' ') path(s) differ only in case; see README.md"
