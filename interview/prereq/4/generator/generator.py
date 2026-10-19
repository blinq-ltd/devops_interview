#!/usr/bin/env python3
"""
Synthetic request generator for scenario 4 (central observability).

Deliberately injects an unbounded-cardinality label (request_id, a UUID per
request) into a Prometheus metric - this is the "sudden series increase"
the candidate must diagnose and fix via collector-side relabeling, not an
application bug to patch. A correctly-labeled counter is exposed alongside
it so the fix can be verified (request count keeps working; request_id
cardinality growth stops).
"""
import os
import time
import uuid
import logging
import sys

from prometheus_client import Counter, start_http_server

logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger("generator")

INTERVAL = float(os.environ.get("REQUEST_INTERVAL_SECONDS", "1"))
METRICS_PORT = int(os.environ.get("METRICS_PORT", "9090"))

# BAD: request_id is unique per request - every request creates a brand new
# time series that's never reused again. This is the cardinality fault.
requests_by_id = Counter(
    "synthetic_requests_total",
    "Synthetic requests, labeled by request_id (DELIBERATE cardinality fault)",
    ["request_id", "status"],
)

# GOOD: bounded label set, what the fix should look like.
requests_total = Counter(
    "synthetic_requests_bounded_total",
    "Synthetic requests, bounded labels only",
    ["status"],
)


def main():
    start_http_server(METRICS_PORT)
    log.info("serving metrics on :%d/metrics", METRICS_PORT)
    seq = 0
    while True:
        seq += 1
        request_id = str(uuid.uuid4())
        status = "200"
        # request_id is logged (structured log, bounded field - correlation
        # with traces/logs belongs here, NOT in a metric label) but also
        # (deliberately, for the exercise) attached to the metric above.
        log.info("request seq=%d request_id=%s status=%s", seq, request_id, status)
        requests_by_id.labels(request_id=request_id, status=status).inc()
        requests_total.labels(status=status).inc()
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
