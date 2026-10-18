# devops_interview

Infrastructure and application code for Blinq's senior DevOps live-coding
interview lab, run in the isolated `blinq-interviews` AWS account
(`us-east-1`).

## Status

- [x] `infra/workstation` — candidate EC2 workstation (SSH + VS Code Remote-SSH)
- [ ] `infra/eks` — EKS cluster, ECR, node capacity (Kubernetes 1.36)
- [ ] `infra/aurora` — private Aurora PostgreSQL
- [ ] `infra/kafka` — Strimzi-managed Kafka on EKS
- [ ] ALB ingress / ACM cert / test hostname
- [ ] Argo CD + starter Application
- [ ] Observability stack (Grafana, Mimir/Loki/Tempo, Alloy)
- [ ] `apps/` — tiny frontend + API + migrations skeleton for the candidate
- [ ] Prepared/resettable incident scripts (readiness fault, Aurora leak, telemetry cardinality + egress block, Kafka broker fault, Terraform drift)

Scenario source: internal interview guide (not stored in this repo).

## infra/workstation

Provisions a temporary Ubuntu 24.04 EC2 instance the candidate reaches via
SSH / VS Code Remote-SSH. Pinned versions: Terraform 1.14.0, kubectl tracking
EKS 1.36.

Installed tooling: docker, aws-cli v2, kubectl, eksctl, helm, terraform,
argocd CLI, k9s, stern, Kafka CLI tools (`/opt/kafka/bin`), psql, hey (HTTP
load generator).

```bash
cd infra/workstation
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: allowed_ssh_cidrs (candidate's public IP!), candidate_ssh_public_key

terraform init
terraform plan
terraform apply
```

The instance's IAM role is intentionally least-privilege and scoped to
`devops-interview-*` named resources. It does **not** yet grant the
permissions scenario 6 (Terraform maintenance exercise) will need against
the EKS nodegroup — see the `TODO(scenario-6)` note in `infra/workstation/iam.tf`,
to be filled in once `infra/eks` exists.

Give the candidate:
- The private half of the temporary SSH keypair (`candidate_ssh_public_key`'s pair)
- The `candidate_ssh_config` Terraform output, to drop into `~/.ssh/config`

## Teardown

This is a disposable lab for a single interview. After the interview:

```bash
cd infra/workstation && terraform destroy
```
