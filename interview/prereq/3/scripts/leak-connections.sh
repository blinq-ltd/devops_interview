#!/usr/bin/env bash
# Simulates leaked/idle connections under the restricted "loadtest" role.
# Each background psql session holds a connection open via pg_sleep for
# DURATION seconds, consuming part of the roles CONNECTION LIMIT 80
# budget. Mitigation: terminate only these sessions
# (pg_terminate_backend on usename=loadtest), not unrelated ones.
#
# Usage: DB_URI=postgres://loadtest:PASSWORD@HOST:5432/appdb \
#        ./leak-connections.sh COUNT DURATION_SECONDS
set -euo pipefail

COUNT="${1:-40}"
DURATION="${2:-600}"
: "${DB_URI:?Set DB_URI to the loadtest roles connection string}"

echo "Opening $COUNT connections as loadtest, holding ${DURATION}s each..."
pids=()
for i in $(seq 1 "$COUNT"); do
  psql "$DB_URI" -c "SELECT pg_sleep($DURATION);" >/dev/null 2>&1 &
  pids+=($!)
done

echo "${pids[@]}" > /tmp/leak-connections.pids
echo "Started ${#pids[@]} sessions. PIDs saved to /tmp/leak-connections.pids"
echo "To release them early: kill \$(cat /tmp/leak-connections.pids)"
echo "Or from the DB side: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = 'loadtest';"
