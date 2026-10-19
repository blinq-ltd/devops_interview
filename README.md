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
psql, `ab` (HTTP load generator — `hey`'s binary distribution is dead; see
Challenges below).

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
  address for a `/16` — see Challenges.
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
  IAM role — both explicit and static (see Challenges for why
  `enable_cluster_creator_admin_permissions` isn't used instead).

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
parallel). This surfaced several real gaps and one real bug — see
Challenges.

## Teardown

This is a disposable lab for a single interview. After the interview:

```bash
cd infra/eks && terraform destroy
cd ../workstation && terraform destroy
cd ../candidate-access && terraform destroy
```

## Challenges faced and how they were resolved

A log of non-obvious problems hit while building this, in case the same
patterns resurface in `infra/aurora`, `infra/kafka`, or the observability
stack.

**Cloud-init SSH key injection was unreliable.** The first approach wrote
the candidate's/admin's SSH keys into `authorized_keys` from the instance
`user_data` script. This didn't reliably take effect on the `ubuntu` user.
Switched to the standard, guaranteed mechanism instead: a real EC2 key pair
(`ec2_key_pair_name`) passed as the instance's `key_name`, which cloud-init
handles natively at first boot.

**The bootstrap script's `set -e` turned one bad download into total
failure.** The original `user_data.sh.tpl` used `set -euxo pipefail` and
listed the candidate-user/SSH-key setup *after* a block of CLI tool
installs. When `stern`'s download 404'd (its GitHub releases don't publish
a `stern_Linux_x86_64.tar.gz` asset — the real name embeds the version,
`stern_<version>_linux_amd64.tar.gz`), the whole script aborted before ever
creating the candidate user. Fixed by: dropping `-e` in favor of a `step()`
helper that logs-and-continues per best-effort tool install, and moving
candidate-user/SSH-key creation to the very top of the script, before any
optional tooling — SSH access must never depend on a package mirror being
reachable. Also hit stale/moved artifacts for Kafka (3.9.1 404'd; current
mirror only keeps recent releases — moved to 4.4.0) and `hey` (its S3
binary bucket now 403s, and its GitHub releases carry no binary assets at
all, only source) — dropped `hey`, kept `apache2-utils`'s `ab` as the load
generator, already installed as a base package.

**IAM resource-naming mismatch.** The workstation's IAM policy scoped EKS
permissions to `arn:...:cluster/${name_prefix}-*` (`devops-interview-*`),
assumed before `infra/eks` existed. The actual cluster is named `interview`
— `infra/eks`'s own convention, unrelated to the workstation's naming. This
silently broke `eks:DescribeCluster` (and therefore `aws eks
update-kubeconfig`) for the candidate end-to-end. Fixed with a dedicated
`var.eks_cluster_name`, only caught because the candidate path was tested
for real rather than assumed correct from the Terraform plan alone.

**`vpc-cni` installed *after* the node group it's required by — a
deadlock.** The EKS Terraform module's default addon ordering creates
addons after the node group. `vpc-cni` is the CNI plugin nodes need to ever
report `Ready` — so the node group polled `CREATING` for 36 minutes before
AWS gave up (`CREATE_FAILED`, "Unhealthy nodes"), because the one thing that
would have made it healthy was scheduled to install only *after* it
finished. Root-caused via the EKS control-plane `authenticator` CloudWatch
log (enabled via `enabled_log_types`): the node authenticated successfully
(`system:nodes` group granted) within a couple of minutes, but no addon
ever reached `ACTIVE` in that window. Fix: `before_compute = true` on
`vpc-cni` and `kube-proxy` (not `coredns`, which needs a `Ready` node to
schedule onto — the reverse ordering requirement). Recovered the
already-deadlocked cluster live: created both addons manually via `aws eks
create-addon`, imported them into Terraform state, tainted the failed node
group, and let a second apply recreate it — it went `Ready` in 1m41s.

**`enable_cluster_creator_admin_permissions` is re-evaluated every apply,
not frozen to the original creator.** This flag grants EKS cluster-admin to
*whoever's identity is currently running* `terraform apply` — discovered
when verifying `gleb`'s scoped access: a `terraform plan` under his
assumed role showed it wanted to delete the admin access entry for
`tapan_halani` (the original applier) and replace it with one for the
`candidate` role. Applying that plan would have silently revoked
`tapan_halani`'s cluster-admin on the next `apply` by anyone else. Fixed by
disabling the flag and making admin access explicit and static via
`var.cluster_admins`, the same mechanism already used for the workstation's
role.

**IAM-policy generation needs a *create* plan, not a no-op one.** Running
`iam-policy-autopilot` against a `terraform plan` of already-applied
infrastructure produces a thin, read-only-looking policy (no `CreateVpc`,
`CreateCluster`, `CreateRole`, etc.) because the plan itself has nothing to
create. Generated a genuine from-scratch plan instead, against a clean
state-less copy of each module directory (never touching the real state
file), plus a `-destroy` plan against the live state for delete-level
actions. Even then, Autopilot's plan-based analysis — by design — can't see
permissions needed only for Terraform `data` source reads (no "resource
change" to analyze): discovered and added `ec2:DescribeKeyPairs` (the
workstation's `data "aws_key_pair"` lookup of an out-of-band key pair),
`eks:DescribeAddonVersions`, and `ssm:GetParameter` (the EKS-module's
AMI-ID lookup) only by actually running `terraform plan` as gleb and
reading the `AccessDenied` errors one at a time.

**Access-entry recreation races with itself.** Renaming a `for_each` key in
`var.cluster_admins` (e.g. index 0 → index 1 for the same principal when
the list order changes) makes Terraform destroy the old access-entry object
and create a new one for the same IAM principal, as two independent
resources with no implied ordering. Hit this twice: both times, the
`CreateAccessEntry` call fired before the old entry's `DeleteAccessEntry`
had actually completed on AWS's side, failing with
`ResourceInUseException`. Not a config bug — just re-running `terraform
apply` once the first (slower) destroy has actually finished resolves it.

**Caller's public IP kept changing mid-session**, blocking SSH entirely
each time (`allowed_ssh_cidrs` didn't include the new `/32`). Mobile/
residential connections rotate IPs more than office ones; if this recurs,
widen to a known-stable range rather than chasing individual `/32`s.
