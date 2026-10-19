# devops_interview

Infrastructure and application code for Blinq's senior DevOps live-coding
interview lab, run in the isolated `blinq-interviews` AWS account
(`382163918348`, `us-east-1`).

## Status

- [x] `infra/workstation` — candidate EC2 workstation (SSH + VS Code Remote-SSH)
- [x] `infra/eks` — EKS cluster "interview" (Kubernetes 1.36), VPC, node group, VPC peering to the workstation
- [x] `infra/candidate-access` — scoped IAM user/role so the candidate can run Terraform themselves (scenario 6)
- [ ] `infra/aurora` — private Aurora PostgreSQL
- [ ] `infra/kafka` — Strimzi-managed Kafka on EKS
- [ ] ECR, ALB ingress / ACM cert / test hostname, GitHub Actions OIDC
- [ ] Argo CD + starter Application
- [ ] Observability stack (Grafana, Mimir/Loki/Tempo, Alloy)
- [ ] `apps/` — tiny frontend + API + migrations skeleton for the candidate
- [ ] Prepared/resettable incident scripts (readiness fault, Aurora leak, telemetry cardinality + egress block, Kafka broker fault, Terraform drift)
- [ ] `interview/prereq/<n>` and `interview/steps/<n>` per scenario (1,2,3,4,6 — Kafka/5 skipped)

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

## Teardown

This is a disposable lab for a single interview. After the interview:

```bash
cd infra/eks && terraform destroy
cd ../workstation && terraform destroy
cd ../candidate-access && terraform destroy
```
