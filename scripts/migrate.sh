#!/usr/bin/env bash
# Apply the interface's SQL migrations to a demo host.
#
# db/schema.sql is a point-in-time dump, so anything added after it exists
# only as a migration. Without this step users_api.php dies with
# "Unknown column 'allowed_contexts'" and user management is unusable.
#
# The migrations are read off the host, not out of a workstation build/
# directory. They ship inside signlab_signCollect-v2, which the host clones
# to $WEBROOT/menu_beta itself; taking them from anywhere else would mean
# applying a set of migrations that does not match the code being served.
#
# Applied migrations are recorded in schema_migrations so re-running is safe.
# The migrations themselves are not all idempotent, so the table is the guard.
#
# Usage: scripts/migrate.sh --host gomer@demo1
set -euo pipefail

cd "$(dirname "$0")/.."
SC_USAGE='usage: scripts/migrate.sh --host <ssh-target>'
# shellcheck source=scripts/_common.sh
. scripts/_common.sh
sc_parse_common "$@"
sc_require_host
sc_on_error "scripts/migrate.sh $(sc_retry_args)"
sc_doing "applying SQL migrations"
DB=admin_gebarenoverleg
WEBROOT=${WEBROOT:-/web}
SRC=$WEBROOT/menu_beta/migrations

ssh "$HOST" "test -d $SRC" || sc_fail "no migrations directory on the host" \
"$SRC does not exist. The migrations ship inside signlab_signCollect-v2, which
the host clones to $WEBROOT/menu_beta itself - so this means the docroot was
never built, or was built with a different --webroot.

Build it:  scripts/install.sh $(sc_retry_args)"

ssh "$HOST" "sudo mysql $DB -e \"CREATE TABLE IF NOT EXISTS schema_migrations (
  name VARCHAR(255) PRIMARY KEY,
  applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;\""

applied=$(ssh "$HOST" "sudo mysql -N $DB -e 'SELECT name FROM schema_migrations;'" || true)
names=$(ssh "$HOST" "ls -1 $SRC/*.sql 2>/dev/null | xargs -r -n1 basename")

err=$(mktemp "${TMPDIR:-/tmp}/sc-migrate.XXXXXX")
SC_CLEANUP='rm -f "$err"' 
for n in $names; do
  if grep -qxF "$n" <<<"$applied"; then
    printf '  skip    %s\n' "$n"
    continue
  fi
  # Read on the host and piped into mysql there, so the file never crosses
  # the network and the migration applied is provably the one deployed.
  if ssh "$HOST" "sudo mysql $DB < $SRC/$n" 2>"$err"; then
    ssh "$HOST" "sudo mysql $DB -e \"INSERT INTO schema_migrations (name) VALUES ('$n');\""
    printf '  applied %s\n' "$n"
  else
    # A migration that is already reflected in schema.sql fails as a duplicate.
    # Record it so it stops being retried, but say so rather than hiding it.
    if grep -qiE 'duplicate|already exists' "$err"; then
      ssh "$HOST" "sudo mysql $DB -e \"INSERT INTO schema_migrations (name) VALUES ('$n');\""
      printf '  present %s (already in schema)\n' "$n"
    else
      printf '  FAILED  %s: %s\n' "$n" "$(head -1 "$err")"
    fi
  fi
  : > "$err"
done
