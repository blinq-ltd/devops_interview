# Scenario 4 prerequisites: central observability, loss and cardinality

Simplified to a **single cluster** - the original scenario's "three
application clusters and a separate data AWS account" multi-account
topology is explicitly discussion-only per the interview guide ("Full
multi-account HA backends are discussion only"). What's here is real and
hands-on: metrics, logs, a collector (Alloy), and a live cardinality fault.

Stack: `kube-prometheus-stack` (Prometheus + Grafana), `loki` (SingleBinary
mode, filesystem storage), `alloy` (the collector), and a small synthetic
request generator with the scenario's cardinality fault built in.

**Not included**: a tracing backend (Tempo). Adding real traces needs
`apps/api` instrumented with OpenTelemetry, which it currently isn't -
flagged as a gap, not faked. The ★ question about Alloy-stopped behavior
across "logs, scraped metrics and traces" is answerable for metrics/logs
live; traces stay conceptual until this is built.

## Setup (run from the workstation)

```bash
kubectl apply -f namespace.yaml
kubectl apply -f generator-deployment.yaml   # build/push generator/ first if rebuilding

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --version 92.10.1 -n observability -f kube-prometheus-stack-values.yaml

helm install loki grafana/loki --version 7.3.0 -n observability -f loki-values.yaml

helm install alloy grafana/alloy --version 1.13.1 -n observability \
  -f alloy-values.yaml --set-file alloy.configMap.content=alloy-config.alloy
```

Grafana admin password:
```bash
kubectl --namespace observability get secrets kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d
kubectl port-forward -n observability svc/kube-prometheus-stack-grafana 3000:80
```

## The cardinality fault (starting state)

`generator/generator.py` exposes `synthetic_requests_total{request_id=...,
status=...}` - a brand new `request_id` (UUID) on every single request, so
the series count grows without bound. `alloy-config.alloy`'s
`prometheus.relabel "generator"` block is the fix point: it has no rule
dropping `request_id` yet. Candidate's task: add
```
rule {
  action = "labeldrop"
  regex  = "request_id"
}
```
and show new-series creation stop (`count(synthetic_requests_total)` stops
climbing) while still correlating a specific request via its logged
`request_id` (already present in the generator's structured logs, shipped
to Loki via `loki.source.kubernetes` - correctly NOT in the metric once
fixed).

A correctly-bounded counter, `synthetic_requests_bounded_total{status}`, is
exposed alongside the faulty one for comparison/verification.

## Status

Applied and verified 2026-10-19, all pods `Running`/`Ready`:
- `count(synthetic_requests_total)` = 226 after ~226 scraped requests -
  confirms 1 series per request (the fault, live and measurable).
- `synthetic_requests_bounded_total` = a single series, value 226 - confirms
  the "what it should look like" comparison works.
- Loki has the generator's logs (`job="loki.source.kubernetes.pods"`,
  `instance` = pod name), each line containing the `request_id` that
  correlates to a metric scrape at the same timestamp - this is the
  concrete answer to "where does request_id belong."
- Grafana running (3/3), Loki added as a datasource automatically via
  `additionalDataSources` in the kube-prometheus-stack values.

Node headroom after the full stack (CloudNativePG + Argo CD + this):
~31-37% CPU, ~13-18% memory used on 2x t3.large - comfortable room left for
the candidate's own scenario-1 deployment alongside all of this.

## What's deliberately NOT done here

- The labeldrop fix itself - candidate's task.
- The 30-60s collector-egress-block exercise and the "Alloy stopped for 5
  minutes" exercise - both run live during the interview (see
  `interview/steps/4/`), not pre-baked, since they're about observing
  behavior during a real outage window.
- Tracing (Tempo) - see note above.
- Multi-account/multi-cluster topology - discussion only, by design.
