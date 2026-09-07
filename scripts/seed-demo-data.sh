#!/usr/bin/env bash
# Seed the demo host with 20 real studio recordings and their videos.
#
# db/schema.sql builds an empty database and db/demo-user.sql adds one login.
# That is enough to sign in and nothing else: every list is empty, no video
# player has a source, and the interface cannot actually be shown to anyone.
# This is the third seed layer - db/demo-data.sql (the rows) plus the MP4s
# named in db/demo-media.txt (the videos those rows point at).
#
# WHERE THE MEDIA COMES FROM
#
# From git, like everything else this deploy ships. The files - 292 of them,
# 291MB - live in the private repository
# Amsterdam-Humanities-Labs/signlab_demo-media, which scripts/repos.tsv lists
# as the gebarenoverleg_media component. So scripts/clone.sh fetches them and
# scripts/deploy.sh puts them on the host, and by the time this script runs
# they are already at /web/gebarenoverleg_media/studioFilesMini/{raw,post}/.
#
# All five camera angles, and their thumbnails. The 20 takes are filmed from
# L, M, R and - on thirteen of them - A and B, each a separate file named in
# its own matched_transcriptions column and each with a .jpg beside the .mp4.
# Only the M angle used to be here, which was invisible in the players that
# ask for m_file and glaring in studioIndex, whose grid requests every angle's
# thumbnail on load and got a wall of 404s. db/demo-media.txt lists all 86
# angles and which cuts each one has.
#
# This used to rsync them out of production into a gitignored workstation
# cache (media/demo/) and push from there. That made the deploy dependent on
# signcollect.nl in a way nothing else was, and the dependency was invisible
# while the cache was warm: a fresh checkout with production unreachable got a
# fully populated interface in which no video played. The production fetch is
# gone rather than kept behind a flag, because a fallback that dials
# production is a fallback nobody runs and nobody tests, and "this deploy
# never touches production" is worth more as a fact than as a default. The
# files are still on production and the repository is how you get them; if it
# ever needs re-filling, that is a deliberate, reviewed copy into
# signlab_demo-media and not a step of the install.
#
# MEDIA_SRC overrides where the checkout is, for running this against a tree
# clone.sh has not built.
#
# WHY THE PUSH RUNS HERE AND NOT ON THE HOST
#
# dev2 is firewalled from production by scripts/isolate.sh and verify.sh
# asserts it stays that way, and it has no GitHub credentials either. Same
# shape as scripts/clone.sh: this workstation reaches git, the demo host
# reaches nothing. The rsync below is normally a no-op - deploy.sh has just
# sent the identical tree - and exists so this script also works on its own,
# against a host deployed earlier.
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
#     hardcodes the same two prefixes. It is also why signlab_demo-media is
#     laid out as studioFilesMini/{raw,post}/ and mapped onto
#     /web/gebarenoverleg_media - the repository holds production's own paths,
#     so deploying it is an ordinary component rsync with no special case.
#
#   /media/<file>
#     apache/signcollect-mounts.conf aliases /media to /web/media_stub,
#     standing in for media.signcollect.nl - whose DocumentRoot on production
#     is studioFilesMini/post. So /media/X.mp4 and .../post/X.mp4 are the same
#     file there, and several components (signlab_zin zinnenVideoStatus and
#     zinCrop, signlab_hh, signlab_mocapStudio, signlab_videoFix) reach for
#     the /media spelling. They are hard-linked rather than copied: one inode,
#     both names, no second 34MB on disk and no reliance on FollowSymLinks
#     being inherited into the media_stub Directory block. The linking stays
#     here rather than moving into the deploy because it is a second name for
#     files deploy.sh has already placed, not a second thing to place.
#
# Usage: HOST=demovps scripts/seed-demo-data.sh
#        HOST=demovps SQL_ONLY=1 scripts/seed-demo-data.sh   # skip all media
set -euo pipefail

cd "$(dirname "$0")/.."
HOST=${HOST:-demovps}
DB=admin_gebarenoverleg
MEDIA_SRC=${MEDIA_SRC:-build/signlab_demo-media/studioFilesMini}
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

# db/demo-media.txt is <stem><TAB><cuts>, one line per camera angle. Read in a
# loop rather than with mapfile: macOS still ships bash 3.2 and this runs from
# a workstation. Two parallel arrays instead of an associative one for the same
# reason - bash 3.2 has no declare -A.
stems=(); cuts=(); post_stems=()
while read -r stem c; do
  case "$stem" in ''|\#*) continue ;; esac
  stems+=("$stem"); cuts+=("$c")
  case " $c " in *" post "*) post_stems+=("$stem") ;; esac
done < db/demo-media.txt
echo "== media (${#stems[@]} angles, ${#post_stems[@]} of them post-processed) =="

[ -d "$MEDIA_SRC/raw" ] && [ -d "$MEDIA_SRC/post" ] || {
  echo "  $MEDIA_SRC is not there - run scripts/clone.sh first, or set" >&2
  echo "  MEDIA_SRC to a signlab_demo-media checkout's studioFilesMini/" >&2
  exit 1
}

# db/demo-media.txt is the list the SQL was written against; the checkout is
# what is on disk. Checking one against the other here means an angle added to
# the seed without its files fails loudly on this workstation instead of
# quietly serving a 404 to a player on the demo.
#
# Both extensions, because studioIndex asks for both: the .mp4 on hover and the
# .jpg thumbnail on every page load. The .jpg was the thing missing when this
# repository held only the M angle - the videos played and the grid was 404s.
missing=0; want=0
i=0
while [ $i -lt ${#stems[@]} ]; do
  s=${stems[$i]}
  for dir in ${cuts[$i]}; do
    for ext in mp4 jpg; do
      want=$((want+1))
      [ -f "$MEDIA_SRC/$dir/$s.$ext" ] || { echo "  MISSING $dir/$s.$ext" >&2; missing=$((missing+1)); }
    done
  done
  i=$((i+1))
done
[ "$missing" -eq 0 ] || { echo "  $missing file(s) missing from $MEDIA_SRC" >&2; exit 1; }
echo "  $MEDIA_SRC holds all $want files ($(du -sh "$MEDIA_SRC" | cut -f1))"

echo "== push =="
# deploy.sh has normally just sent this exact tree as the gebarenoverleg_media
# component, so this transfers nothing; it is here so the script stands alone.
# mkdir for the case where it has not - a host provisioned but not yet
# deployed, or SQL seeded before the components went out.
ssh "$HOST" "mkdir -p $HOST_MEDIA/raw $HOST_MEDIA/post /web/media_stub"
for dir in raw post; do
  rsync -a "$MEDIA_SRC/$dir/" "$HOST:$HOST_MEDIA/$dir/"
  echo "  $dir -> $HOST_MEDIA/$dir/"
done

# /media/<file> == post/<file>, as it is on production - that alias stands in
# for media.signcollect.nl, whose DocumentRoot is post/. Thumbnails as well as
# video: the same directory serves both there. ln -f so a re-run relinks rather
# than failing, and only for what we seeded - media_stub is not ours to mirror
# wholesale.
ssh "$HOST" "set -e
  for s in ${post_stems[*]}; do
    ln -f '$HOST_MEDIA/post/'\$s.mp4 /web/media_stub/\$s.mp4
    ln -f '$HOST_MEDIA/post/'\$s.jpg /web/media_stub/\$s.jpg
  done"
echo "  ${#post_stems[@]} post cuts hard-linked into /web/media_stub, mp4 and jpg (serves /media/<stem>.<ext>)"

echo
echo "done. Check one: curl -sI https://<domain>/gebarenoverleg_media/studioFilesMini/post/${post_stems[0]}.mp4"
