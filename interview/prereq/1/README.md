# Scenario 1 prerequisites: EKS (done in infra/eks) + a database for the app

Run from the workstation (`kubectl`/`helm` already point at the `interview`
cluster there).

## 1. Default to a CSI-backed gp3 StorageClass

```bash
kubectl apply -f 00-storageclass-gp3.yaml
```

## 2. Install the CloudNativePG operator

Pinned: chart `0.29.1`, operator image `1.30.1`.

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
helm install cnpg-operator cnpg/cloudnative-pg \
  --version 0.29.1 \
  --namespace cnpg-system --create-namespace
kubectl rollout status deployment/cnpg-controller-manager -n cnpg-system
```

## 3. Create the database

```bash
kubectl apply -f 00-namespace.yaml
kubectl apply -f cluster.yaml
kubectl wait --for=condition=Ready cluster/interview-db -n cnpg-database --timeout=5m
```

This creates:
- A single-instance Postgres 16.6 cluster, `gp3`-backed 5Gi volume
- An empty `appdb` database owned by `appuser`
- A Secret `interview-db-app` in namespace `cnpg-database` with keys
  `user`, `password`, `host`, `port`, `dbname`, `uri` — give the candidate
  this secret's **name**, not its contents; they wire it into their own
  Deployment/ExternalSecret.

## Verify

```bash
kubectl get cluster -n cnpg-database
kubectl get secret interview-db-app -n cnpg-database -o jsonpath='{.data.uri}' | base64 -d; echo
```

## What's deliberately NOT done here

- No schema/tables — the candidate's app ships a `npm run migrate` command
  (`apps/api/src/migrate.js`) that creates them. Don't pre-run it; that's
  part of what's being evaluated.
- No Dockerfile, Helm chart, Kustomize overlay, or CI pipeline for
  `apps/api` — the candidate builds and deploys all of that live.
