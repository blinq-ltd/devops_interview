# devops_interview

Infrastructure and application code for Blinq's senior DevOps live-coding
interview lab, run in the isolated `blinq-interviews` AWS account
(`382163918348`, `us-east-1`).

## Status

- [x] `infra/workstation` — candidate EC2 workstation (SSH + VS Code Remote-SSH)
- [x] `infra/eks` — EKS cluster "interview" (Kubernetes 1.36), VPC, 2-node t3.large node group, VPC peering to the workstation, ECR (api + generator repos)
- [x] `infra/candidate-access` — scoped IAM user/role so the candidate can run Terraform themselves (scenario 6)
- [x] `apps/api` — minimal Node.js CRUD API (GET/POST/PUT `/items`) backed by Postgres; candidate containerizes/deploys it (scenario 1)
- [x] Scenario 1 prereqs — CloudNativePG database (`interview-db`), gp3 default StorageClass
- [x] Scenario 2 prereqs — Argo CD + an interviewer-owned baseline deployment, degraded on purpose (wrong readiness path)
- [x] Scenario 3 prereqs — restricted `loadtest` DB role (connection-limit incident), CloudNativePG-native PgBouncer `Pooler`, load-generation scripts
- [x] Scenario 4 prereqs — single-cluster observability stack (Prometheus/Grafana, Loki, Alloy) with a live, verified cardinality fault
- [x] Scenario 6 prereqs — prepared Terraform change (harmless tag + disruptive node-group replacement) with a saved plan
- [ ] Scenario 5 (Kafka) — **explicitly skipped** per instruction
- [ ] ALB ingress / ACM cert / test hostname (`test-int.blinqme.com`) — no externally-reachable HTTPS endpoint yet, see `interview/prereq/1/README.md`
- [ ] GitHub Actions OIDC trust — left to the candidate to build (scenario 1, discussion ★Q1)
- [ ] Tracing backend (Tempo) — `apps/api` isn't instrumented; traces stay conceptual in scenario 4
- [ ] `interview/aurora` — not applicable: scenario 3 was adapted to use the self-hosted CloudNativePG database instead of AWS RDS Aurora (see `apps/api`/scenario 3 prereq README for why)

Per-scenario prerequisites live in `interview/prereq/<n>/` (committed,
IaC/k8s code). Interviewer-only fault-injection/reset runbooks live in
`interview/steps/<n>/` — **gitignored, local-only, never shared with
candidates**.

Scenario source: internal interview guide (not stored in this repo).

## infra/workstation

Provisions a temporary Ubuntu 24.04 EC2 instance the candidate reaches via
SSH / VS Code Remote-SSH. Pinned versions: Terraform 1.14.0, kubectl tracking
EKS 1.36.

Installed tooling: docker, aws-cli v2, kubectl, eksctl, helm, terraform,
argocd CLI, k9s, stern, kcat/kafkacat, Kafka CLI tools (`/opt/kafka/bin`),
psql, `ab` (HTTP load generator — `hey`'s binary distribution is dead).

```bash
cd infra/workstation
cp terraform.tfvars.example terraform.tfvars
# edit: allowed_ssh_cidrs (candidate's public IP!), candidate_ssh_public_key,
# admin_ssh_public_keys, additional_internal_cidrs (the infra/eks VPC CIDR)

terraform init
terraform plan
terraform apply
```

Two separate Linux users on the box:
- `candidate` — what the candidate SSHes in as. Scoped IAM role via the
  instance profile (see `infra/workstation/iam.tf`), `sudo`+`docker` group.
- `ubuntu` — interviewer/admin access, via the EC2 key pair
  (`ec2_key_pair_name` var) plus any `admin_ssh_public_keys`.

Give the candidate:
- The private half of the temporary SSH keypair (matching `candidate_ssh_public_key`)
- The `candidate_ssh_config` Terraform output, to drop into `~/.ssh/config`

## infra/eks

EKS cluster `interview`, Kubernetes 1.36, **private-only API endpoint** —
reachable only from the workstation, via VPC peering.

```bash
cd infra/eks
cp terraform.tfvars.example terraform.tfvars
# edit: cluster_admins, workstation_iam_role_arn, workstation_vpc_id,
# workstation_vpc_cidr, workstation_security_group_id (from
# `cd ../workstation && terraform output`)

terraform init
terraform plan
terraform apply
```

- VPC `100.15.0.0/20`, 3 public + 3 private subnets across 3 AZs, single NAT
  gateway (cost-efficient; not cross-AZ HA — this is a short-lived lab).
  Corrected from the requested `100.15.8.0/16`, which isn't a valid network
  address for a `/16`.
- Managed node group: `t3.small`, 1/1/1, AL2023, IMDSv2-only, KMS-encrypted
  gp3 volumes.
- Addons (`most_recent = true`, tracks EKS 1.36 compatibility): `vpc-cni`,
  `coredns`, `kube-proxy`, `aws-ebs-csi-driver` (dedicated IRSA role, AWS
  managed `AmazonEBSCSIDriverPolicy`).
- `infra/eks/modules/vpc_peering` — on/off via `var.enable_vpc_peering`.
  Peers the EKS VPC with the workstation's VPC, adds routes on both sides,
  and opens the cluster's security group to port 443 **only from the
  workstation's security group** (not its CIDR) — nothing else can reach
  the private API.
- EKS access entries grant `AmazonEKSClusterAdminPolicy` to
  `var.cluster_admins` (currently `tapan_halani`) and to the workstation's
  IAM role — both explicit and static. (`enable_cluster_creator_admin_permissions`
  is deliberately disabled: it ties admin access to whoever's identity is
  currently running `terraform apply`, re-evaluated every apply, rather
  than being frozen to the original creator.)

Validated end-to-end exactly as the candidate would, from the workstation:
SSH as `candidate` → `aws eks update-kubeconfig` → `kubectl auth can-i '*' '*'`
→ `yes` → deployed/exposed/curled nginx (HTTP 200 via port-forward) → cleaned
up. tfsec clean (54 passed, 3 documented ignores — see inline `#tfsec:ignore`
comments for why each is a false positive or an accepted, justified risk).

## infra/candidate-access

IAM user `gleb` (the candidate) with only `sts:AssumeRole` on a `candidate`
IAM role — all actual permissions live on that role, scoped to exactly what
`terraform plan`/`apply`/`destroy` needs for `infra/workstation` + `infra/eks`.

```bash
cd infra/candidate-access
terraform init
terraform plan
terraform apply

# retrieve the one-time secret (do not paste it anywhere persistent):
terraform output -raw gleb_secret_access_key
terraform output aws_cli_profile_snippet   # gives gleb the ~/.aws config to use
```

Gleb then runs `AWS_PROFILE=gleb terraform plan -var="aws_profile=gleb"`
inside `infra/workstation` or `infra/eks` (the `-var` override points the
module's own `aws` provider at his profile instead of the interviewer's
`blinq-interviews` one).

The policy was generated per this account's `aws-iam` skill's **mandatory**
workflow: `uvx iam-policy-autopilot generate-policies` against real
Terraform plan JSON, not hand-written. Two plan types were needed —
a full-create plan (via a clean, state-less copy of each module directory)
*and* a `-destroy` plan against the live state — because a plan against
infra that's already fully applied only yields read-level actions, not the
create/delete ones actually needed to provision from scratch. Autopilot's
five duplicate, unscoped `iam:PassRole` statements were consolidated into
one, restricted by `iam:PassedToService` (`ec2`/`eks` only), per this same
skill's documented guidance on the PassRole + RunInstances/CreateCluster
privilege-escalation pattern — this stack's IAM roles don't share one name
prefix, so resource-ARN scoping alone wasn't viable.

Verified by actually assuming the role and running `terraform plan` against
both modules with zero permission errors and zero real drift (confirmed
against a plan run with the interviewer's own admin credentials in
parallel).

## apps/api

The candidate-facing starting point for scenario 1: a minimal Express/pg
CRUD API (`GET`/`POST`/`PUT /items`, `/livez`, `/readyz`), with a
documented `npm run migrate` command but deliberately **no** Dockerfile,
Helm chart/Kustomize overlay, or CI pipeline — the candidate builds and
deploys all of that live. See `apps/api/README.md`.

## interview/

Per-scenario lab material, numbered to match the interview guide's
scenarios (1, 2, 3, 4, 6 — scenario 5/Kafka is explicitly skipped):

- `interview/prereq/<n>/` — everything that must already be running before
  the candidate starts: IaC/Helm/k8s manifests, committed and pushed like
  any other code here. Each has its own README with setup steps and a
  verified "Status" section.
- `interview/steps/<n>/` — the interviewer's own runbook: how to inject
  each scenario's fault, what "fixed" looks like, which discussion
  questions are live-testable and how, and how to reset between
  candidates. **Gitignored, local-only — never shared with a candidate.**

Scenario 3 was adapted from the original "Aurora connection incident" to
use the self-hosted CloudNativePG database provisioned in
`interview/prereq/1/` instead of AWS RDS Aurora — same diagnostic approach
(`pg_stat_activity`, connection budgets, pooling), no AWS RDS involved.
Scenario 4's observability stack is simplified to this single cluster; the
original's multi-cluster/separate-data-account topology stays
discussion-only, per the interview guide itself.

## Teardown

This is a disposable lab for a single interview. After the interview:

```bash
# uninstall in-cluster stacks first (from the workstation)
helm uninstall alloy loki kube-prometheus-stack -n observability
helm uninstall argocd -n argocd
helm uninstall cnpg-operator -n cnpg-system
kubectl delete namespace observability argocd cnpg-database interview-baseline

# then tear down the AWS infra
cd infra/eks && terraform destroy
cd ../workstation && terraform destroy
cd ../candidate-access && terraform destroy
```
