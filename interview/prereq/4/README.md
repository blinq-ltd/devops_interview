# Scenario 4 prerequisites: central observability, loss and cardinality

Simplified to a **single cluster** - the original scenario's "three
application clusters and a separate data AWS account" multi-account
topology is explicitly discussion-only per the interview guide.

Stack: `kube-prometheus-stack` (Prometheus + Grafana), `loki` (SingleBinary
mode, filesystem storage), `alloy` (the collector), and a small synthetic
request generator (`generator/`).

**Not included**: a tracing backend (Tempo). `apps/api` isn't instrumented
with OpenTelemetry.

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

See `interview/questions/4.md` for the candidate-facing task description.
