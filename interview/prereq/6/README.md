# Scenario 6 prerequisites: Terraform drift, EKS maintenance and scaling

The candidate already has everything they need to *run* this exercise
(their own scoped `candidate` IAM role from `infra/candidate-access`,
working `terraform plan`/`apply` against `infra/eks` - see its own README).
What's prepared here is the **reviewable change itself**.

## The prepared change

- `candidate-starting.tfvars` — a committed snapshot of the real
  `infra/eks/terraform.tfvars` as it stood when this was prepared (that
  file itself is gitignored - this is so the exercise stays reproducible
  across candidates even after the real one has moved on, e.g. after
  scenario-driven node group resizes).
- `proposed-change.tfvars` — the same file with two changes bundled, exactly
  matching the scenario prompt ("harmless tag drift and a disruptive
  node-group change"):
  1. A new `CostCenter` tag added to `resource_tags` (harmless - shows as
     an update across every tagged resource).
  2. `node_group_map.default.capacity_type` changed `ON_DEMAND` → `SPOT`
     (disruptive - the EKS API doesn't support changing this on an
     existing node group, so Terraform must replace it entirely).
- `saved-plan.txt` — the actual `terraform plan` output against
  `proposed-change.tfvars`, saved for fast initial inspection (per the
  scenario: "a saved plan for fast initial inspection"). Confirmed:
  `Plan: 2 to add, 41 to change, 1 to destroy`, with
  `module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]
  must be replaced` explicitly called out.

## Running it with the candidate

```bash
cd infra/eks
diff interview/prereq/6/candidate-starting.tfvars interview/prereq/6/proposed-change.tfvars
# hand them proposed-change.tfvars (or let them generate their own plan)
terraform plan -var-file=../../interview/prereq/6/proposed-change.tfvars
```

Correct answer separates the two: apply the tag change alone (safe,
rehearsed - see below), and either don't make the `capacity_type` change at
all without a maintenance window + scale-up-first/drain sequence, or
achieve a spot-capacity goal without disrupting the existing node group -
e.g. a **second** node group with `capacity_type = "SPOT"` alongside the
existing on-demand one, migrating workloads onto it gradually, rather than
converting the existing one in place.

## What's safe to actually apply (rehearsed)

The tag-only change is safe and was test-applied once (see
`interview/steps/6/`, local-only, for the exact rehearsal). **Do not** apply
`proposed-change.tfvars` as-is during the interview - that executes the
disruptive node-group replacement for real, including evicting whatever the
candidate deployed in scenarios 1/2/3/4.

## What's deliberately NOT done here

- No control-plane (Kubernetes version) upgrade is staged - the scenario
  explicitly says not to perform one during the interview. The "sequence
  for a later EKS/node upgrade" question is discussion-only.
- No actual application rollout is pre-staged - the candidate demonstrates
  one live against whatever's already deployed (scenario 1/2's app), per
  the scenario's 10-minute default path.
