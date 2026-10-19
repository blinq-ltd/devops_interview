# Scenario 6 prerequisites: Terraform drift, EKS maintenance and scaling

The candidate already has what they need to *run* this exercise (their own
scoped `candidate` IAM role from `infra/candidate-access`, working
`terraform plan`/`apply` against `infra/eks`). What's prepared here is the
reviewable change itself.

## Files

- `candidate-starting.tfvars` — a committed snapshot of the real
  `infra/eks/terraform.tfvars` (that file itself is gitignored).
- `proposed-change.tfvars` — a proposed change to review, relative to
  `candidate-starting.tfvars`.
- `saved-plan.txt` — the `terraform plan` output against
  `proposed-change.tfvars`, for fast initial inspection.

## Running it with the candidate

```bash
cd infra/eks
diff interview/prereq/6/candidate-starting.tfvars interview/prereq/6/proposed-change.tfvars
terraform plan -var-file=../../interview/prereq/6/proposed-change.tfvars
```

**Do not apply `proposed-change.tfvars` as-is during the interview** -
depending on what the candidate's review concludes, applying it as given
may not be safe. See `interview/questions/6.md` for the candidate-facing
task description.
