# Scenario 2 prerequisites: Argo CD + an already-managed baseline app

This is an **interviewer-owned** copy of `apps/api`, separate from whatever
the candidate builds in scenario 1.

## Setup (run from the workstation)

```bash
# 1. Build and push the baseline image
docker build -f app-image/Dockerfile -t <ecr-repo>:baseline ../../..   # repo root as build context
docker push <ecr-repo>:baseline

# 2. Install Argo CD
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd --version 10.10.5 --namespace argocd --create-namespace

# 3. One-time manual namespace + DB secret copy (NOT Argo-managed - see namespace.yaml)
kubectl apply -f namespace.yaml
kubectl get secret interview-db-app -n cnpg-database -o json | \
  python3 -c "import json,sys; d=json.load(sys.stdin); d['metadata']={'name':d['metadata']['name'],'namespace':'interview-baseline'}; print(json.dumps(d))" | \
  kubectl apply -f -

# 4. Repo credentials for Argo CD (read-only deploy key, generated once -
#    see notes.md for how it was created; the private key itself is NOT in
#    this repo)
kubectl create secret generic devops-interview-repo-creds -n argocd \
  --from-literal=type=git \
  --from-literal=url=git@github.com:blinq-ltd/devops_interview.git \
  --from-file=sshPrivateKey=<path-to-deploy-key> \
  --dry-run=client -o yaml | \
  kubectl label --local -f - argocd.argoproj.io/secret-type=repository -o yaml --dry-run=client | \
  kubectl apply -f -

# 5. AppProject + Application
kubectl apply -f argocd/appproject.yaml
kubectl apply -f argocd/application.yaml
```

See `interview/questions/2.md` for the candidate-facing task description.
