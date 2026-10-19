# Scenario 3 prerequisites: connection incident + pooling

Adapted from the original "Aurora" scenario to the self-hosted CloudNativePG
database (`interview-db`, see `interview/prereq/1/`) - same exercise, same
diagnostic SQL, no AWS RDS involved.

## 1. Restricted test role

Creating a role needs `CREATEROLE`, which the app's own `appuser` doesn't
have (and shouldn't). `infra/prereq/1/cluster.yaml` sets
`enableSuperuserAccess: true` for this, generating an
`interview-db-superuser` Secret (interviewer/admin use only - never give
this to the candidate). Its `uri` has a literal `*` in place of a database
name (a superuser isn't bound to one DB) - substitute a real one:

```bash
PW=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
sed "s/__PASSWORD__/$PW/" role.sql.template > /tmp/role.sql
SUPERUSER_URI=$(kubectl get secret interview-db-superuser -n cnpg-database -o jsonpath='{.data.uri}' | base64 -d | sed 's#/\*$#/postgres#')
kubectl run psql-setup --rm -i --restart=Never --image=postgres:16-alpine -n cnpg-database -- \
  psql "$SUPERUSER_URI" < /tmp/role.sql
rm -f /tmp/role.sql
# save $PW somewhere the interviewer can retrieve it (not in git) - the
# load scripts need it as part of DB_URI
```

## 2. PgBouncer pooler (CloudNativePG-native)

```bash
kubectl apply -f pooler.yaml
kubectl get pods -n cnpg-database -l cnpg.io/poolerName=interview-db-pooler   # 2/2 Running
```

Creates a `interview-db-pooler` Service (port 5432) in `cnpg-database` -
this is what the candidate's canary points at instead of `interview-db-rw`
directly. (Pooler resources don't expose a `condition=Ready` the way
Clusters do - check pod readiness instead.)

## 3. Load scripts (`scripts/`)

- `leak-connections.sh <count> <duration>` — simulates leaked/idle
  connections under the `loadtest` role (its own `CONNECTION LIMIT 80`
  keeps this isolated from the app's real `appuser` connections and from
  the instance-wide `max_connections`).
- `synthetic-client.sh [interval] [logfile]` — continuous HTTP client
  against the candidate's deployed app, logging timestamp/status/latency to
  CSV. Start this *before* any disruptive step.

Run both from the workstation, not pre-started - they're part of the live
exercise (see `interview/steps/3/`, local-only).

## Status

Applied and verified 2026-10-19: `loadtest` role created with `CONNECTION
LIMIT 80`, grants `CONNECT` on `appdb`. `interview-db-pooler` `Pooler`
healthy (2/2 pgbouncer pods), `interview-db-pooler` Service present.
`leak-connections.sh` tested end-to-end against the real role: opened 90
connections total (40 + 50 in two batches), confirmed exactly 80 active in
`pg_stat_activity` under `usename = 'loadtest'`, and the overflow attempt
failed with Postgres's own `FATAL: too many connections for role
"loadtest"` - confirms the role-level limit (not instance-wide
`max_connections`) is what's actually being exercised. Cleaned up via
`pg_terminate_backend` afterward.

**Important for the live session**: `interview-db-rw`/`interview-db-pooler`
are cluster-internal DNS names, not resolvable from the workstation
directly (it's peered at the network/IP level, not part of the cluster's
pod network/CoreDNS). Candidates need `kubectl port-forward` (or run the
load scripts as in-cluster Jobs/Pods) to reach the database from the
workstation shell - see `interview/steps/3/`.

## What's deliberately NOT done here

- No app deployment pointed at the pooler yet — the candidate's canary
  cutover is their task.
- The actual incident (running `leak-connections.sh` against a live,
  scaled-up candidate deployment) is run live, not pre-baked — see
  `interview/steps/3/`.
