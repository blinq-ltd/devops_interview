#!/usr/bin/env bash
# Continuous synthetic client: records every request's timestamp, HTTP
# status, and latency to a CSV log, so "a short successful test" can be
# told apart from "the incident never actually happened" after the fact.
# Run this BEFORE any disruptive exercise (connection leak, pool resize,
# canary cutover) and leave it running throughout.
#
# Usage: TARGET_URL=http://<svc>:<port>/items ./synthetic-client.sh [interval_seconds] [logfile]
set -euo pipefail

: "${TARGET_URL:?Set TARGET_URL, e.g. http://devops-interview-api.interview-baseline.svc.cluster.local/items}"
INTERVAL="${1:-1}"
LOGFILE="${2:-/tmp/synthetic-client.csv}"

echo "timestamp,http_code,time_total_s" > "$LOGFILE"
echo "Logging to $LOGFILE every ${INTERVAL}s against $TARGET_URL (Ctrl-C to stop)"

while true; do
  ts=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
  read -r code total < <(curl -s -o /dev/null -w "%{http_code} %{time_total}" --max-time 5 "$TARGET_URL" || echo "000 5.000")
  echo "$ts,$code,$total" >> "$LOGFILE"
  sleep "$INTERVAL"
done
