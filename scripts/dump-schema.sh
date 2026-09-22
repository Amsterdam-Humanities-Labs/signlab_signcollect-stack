#!/usr/bin/env bash
# Print the structure (no rows) of the SignCollect database to stdout.
# Read-only: mysqldump --no-data with --single-transaction takes no table locks
# and writes nothing to the server.
#
# Run it ON the database host, as a user MySQL lets in (socket auth: sudo):
#   sudo scripts/dump-schema.sh > schema.sql
#   sudo scripts/dump-schema.sh -d other_db > other.sql
# Extra arguments after -- go to mysqldump, e.g. -- -u someone -p
#
# The result replaces interface_deploy/db/schema.sql, which is a subtree:
# commit it upstream, not here. See docs/schema.md for when to re-run.
set -euo pipefail

db=admin_gebarenoverleg
while [ $# -gt 0 ]; do
  case "$1" in
    -d) db="$2"; shift 2 ;;
    --) shift; break ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "usage: $0 [-d database] [-- mysqldump args]" >&2; exit 2 ;;
  esac
done

# DEFINER clauses name production users that do not exist on other hosts;
# AUTO_INCREMENT counters change every insert and only add diff noise.
mysqldump --no-data --single-transaction --skip-lock-tables --no-tablespaces \
  "$@" "$db" \
  | sed -E 's/ DEFINER=`[^`]+`@`[^`]+`//; s/ AUTO_INCREMENT=[0-9]+//'
