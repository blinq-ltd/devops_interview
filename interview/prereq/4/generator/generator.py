#!/usr/bin/env python3
"""
Synthetic request generator for scenario 4 (central observability).
Exposes Prometheus metrics on :9090/metrics and logs each request.
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

requests_by_id = Counter(
    "synthetic_requests_total",
    "Synthetic requests, labeled by request_id",
    ["request_id", "status"],
)

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
        log.info("request seq=%d request_id=%s status=%s", seq, request_id, status)
        requests_by_id.labels(request_id=request_id, status=status).inc()
        requests_total.labels(status=status).inc()
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
