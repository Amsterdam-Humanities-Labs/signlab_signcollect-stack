#!/usr/bin/env bash
# Seed the demo host with 20 real studio recordings and their videos.
#
# db/schema.sql builds an empty database and db/demo-user.sql adds one login.
# That is enough to sign in and nothing else: every list is empty, no video
# player has a source, and the interface cannot actually be shown to anyone.
# This is the third seed layer - db/demo-data.sql (the rows) plus the MP4s
# named in db/demo-media.txt (the videos those rows point at).
#
# WHY THE MEDIA IS NOT IN GIT
#
# The 20 recordings are 40 MP4s - a raw and a post cut each - and 68MB in
# total. Two reasons not to commit them:
#
#   Size. 68MB of already-compressed video does not delta or pack; it would
#   be six times the whole rest of the repo, permanently.
#
#   They are recordings of identifiable research participants. A git object
#   cannot be withdrawn once it is committed, and a demo dataset is exactly
#   the kind of thing that gets re-cloned and passed around. Keeping the
#   video out of history means the decision to move it stays reviewable, and
#   revocable, every time this runs.
#
# So the files are fetched from production into a gitignored cache
# (media/demo/, override with MEDIA_CACHE) and pushed from there. The cache
# makes the fetch a one-off: a second run copies nothing.
#
# WHY THE FETCH RUNS HERE AND NOT ON THE HOST
#
# dev2 is firewalled from production by scripts/isolate.sh and verify.sh
# asserts it stays that way, so the demo host cannot pull anything. Same shape
# as scripts/clone.sh: this workstation reaches both ends, the demo host
# reaches neither. Production is only ever read.
#
# WHERE THE VIDEOS HAVE TO LAND
#
# Two paths, because the code names two:
#
#   /gebarenoverleg_media/studioFilesMini/{raw,post}/<stem>.mp4
#     Docroot-relative, so /web/gebarenoverleg_media/... on the host. This is
#     what actually plays: signCollect-v2 js/main.js and js/table.js build
#     exactly this URL from matched_transcriptions.m_file (stem + .mp4, post/
#     when post_processed=1, raw/ otherwise), and signlab_zin getZinnen.php
#     hardcodes the same two prefixes.
#
#   /media/<file>
#     apache/signcollect-mounts.conf aliases /media to /web/media_stub,
#     standing in for media.signcollect.nl - whose DocumentRoot on production
#     is studioFilesMini/post. So /media/X.mp4 and .../post/X.mp4 are the same
#     file there, and several components (signlab_zin zinnenVideoStatus and
#     zinCrop, signlab_hh, signlab_mocapStudio, signlab_videoFix) reach for
#     the /media spelling. They are hard-linked rather than copied: one inode,
#     both names, no second 34MB on disk and no reliance on FollowSymLinks
#     being inherited into the media_stub Directory block.
#
# Usage: HOST=demovps scripts/seed-demo-data.sh
#        HOST=demovps NO_FETCH=1 scripts/seed-demo-data.sh   # cache only
#        HOST=demovps SQL_ONLY=1 scripts/seed-demo-data.sh   # skip all media
set -euo pipefail

cd "$(dirname "$0")/.."
HOST=${HOST:-demovps}
DB=admin_gebarenoverleg
PROD=${PROD:-signcollect.nl}
CACHE=${MEDIA_CACHE:-media/demo}
PROD_MEDIA=/web/gebarenoverleg_media/studioFilesMini
HOST_MEDIA=/web/gebarenoverleg_media/studioFilesMini

[ -f db/demo-data.sql ]  || { echo "  db/demo-data.sql missing" >&2; exit 1; }
[ -f db/demo-media.txt ] || { echo "  db/demo-media.txt missing" >&2; exit 1; }

# demo-user.sql first, if it has not run: demo-data.sql resolves @demo_user
# from it. It is idempotent, so running it again costs nothing, and seeding
# rows that point at a user who does not exist is the one ordering mistake
# here that is silent.
echo "== login =="
ssh "$HOST" "sudo mysql $DB" < db/demo-user.sql
echo "  demo-user.sql applied"

echo "== rows =="
ssh "$HOST" "sudo mysql $DB" < db/demo-data.sql
counts=$(ssh "$HOST" "sudo mysql -N $DB -e \"
  SELECT (SELECT COUNT(*) FROM CameraRecords),
         (SELECT COUNT(*) FROM matched_transcriptions),
         (SELECT COUNT(*) FROM sentences),
         (SELECT COUNT(*) FROM form_data);\"")
echo "  CameraRecords/matched_transcriptions/sentences/form_data: $counts"

if [ -n "${SQL_ONLY:-}" ]; then
  echo "  SQL_ONLY set - media skipped"
  exit 0
fi

# The stems, comments and blank lines stripped. Read in a loop rather than
# with mapfile: macOS still ships bash 3.2 and this runs from a workstation.
stems=()
while IFS= read -r s; do
  case "$s" in ''|\#*) continue ;; esac
  stems+=("$s")
done < db/demo-media.txt
echo "== media (${#stems[@]} takes, raw + post) =="

mkdir -p "$CACHE/raw" "$CACHE/post"

if [ -n "${NO_FETCH:-}" ]; then
  echo "  NO_FETCH set - using whatever the cache already holds"
else
  # Only ask production for what is missing. rsync --files-from sends one
  # request for the whole batch rather than one ssh per file, and --ignore-
  # existing means a warm cache transfers nothing at all.
  for dir in raw post; do
    want=$(mktemp)
    for s in "${stems[@]}"; do
      [ -f "$CACHE/$dir/$s.mp4" ] || printf '%s.mp4\n' "$s" >> "$want"
    done
    if [ -s "$want" ]; then
      printf '  fetching %s missing from %s/\n' "$(wc -l < "$want" | tr -d ' ')" "$dir"
      rsync -a --files-from="$want" "$PROD:$PROD_MEDIA/$dir/" "$CACHE/$dir/"
    else
      printf '  %-4s cache complete\n' "$dir"
    fi
    rm -f "$want"
  done
fi

missing=0
for s in "${stems[@]}"; do
  for dir in raw post; do
    [ -f "$CACHE/$dir/$s.mp4" ] || { echo "  MISSING $dir/$s.mp4" >&2; missing=$((missing+1)); }
  done
done
[ "$missing" -eq 0 ] || { echo "  $missing file(s) missing from the cache" >&2; exit 1; }
echo "  cache holds $(du -sh "$CACHE" | cut -f1)"

echo "== push =="
# The tree is not part of a component deploy, so deploy.sh does not create it.
ssh "$HOST" "mkdir -p $HOST_MEDIA/raw $HOST_MEDIA/post /web/media_stub"
for dir in raw post; do
  rsync -a "$CACHE/$dir/" "$HOST:$HOST_MEDIA/$dir/"
  echo "  $dir -> $HOST_MEDIA/$dir/"
done

# /media/<file> == post/<file>, as it is on production. ln -f so a re-run
# relinks rather than failing, and only for the stems we seeded - media_stub
# is not ours to mirror wholesale.
ssh "$HOST" "set -e
  for s in ${stems[*]}; do
    ln -f '$HOST_MEDIA/post/'\$s.mp4 /web/media_stub/\$s.mp4
  done"
echo "  ${#stems[@]} post cuts hard-linked into /web/media_stub (serves /media/<stem>.mp4)"

echo
echo "done. Check one: curl -sI https://<domain>/gebarenoverleg_media/studioFilesMini/post/${stems[0]}.mp4"
