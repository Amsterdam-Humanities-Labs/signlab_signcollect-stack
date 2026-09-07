#!/usr/bin/env bash
# Apply the interface's SQL migrations to a demo host.
#
# db/schema.sql is a point-in-time dump, so anything added after it exists
# only as a migration. Without this step users_api.php dies with
# "Unknown column 'allowed_contexts'" and user management is unusable.
#
# Applied migrations are recorded in schema_migrations so re-running is safe.
# The migrations themselves are not all idempotent, so the table is the guard.
#
# Usage: HOST=demovps scripts/migrate.sh
set -euo pipefail

cd "$(dirname "$0")/.."
HOST=${HOST:-demovps}
DB=admin_gebarenoverleg
SRC=build/signlab_signCollect-v2/migrations

[ -d "$SRC" ] || { echo "  no migrations dir - run scripts/clone.sh first" >&2; exit 1; }

ssh "$HOST" "sudo mysql $DB -e \"CREATE TABLE IF NOT EXISTS schema_migrations (
  name VARCHAR(255) PRIMARY KEY,
  applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;\""

applied=$(ssh "$HOST" "sudo mysql -N $DB -e 'SELECT name FROM schema_migrations;'" || true)

for f in "$SRC"/*.sql; do
  n=$(basename "$f")
  if grep -qxF "$n" <<<"$applied"; then
    printf '  skip    %s\n' "$n"
    continue
  fi
  if ssh "$HOST" "sudo mysql $DB" < "$f" 2>/tmp/mig.err; then
    ssh "$HOST" "sudo mysql $DB -e \"INSERT INTO schema_migrations (name) VALUES ('$n');\""
    printf '  applied %s\n' "$n"
  else
    # A migration that is already reflected in schema.sql fails as a duplicate.
    # Record it so it stops being retried, but say so rather than hiding it.
    if grep -qiE 'duplicate|already exists' /tmp/mig.err; then
      ssh "$HOST" "sudo mysql $DB -e \"INSERT INTO schema_migrations (name) VALUES ('$n');\""
      printf '  present %s (already in schema)\n' "$n"
    else
      printf '  FAILED  %s: %s\n' "$n" "$(head -1 /tmp/mig.err)"
    fi
  fi
  rm -f /tmp/mig.err
done
