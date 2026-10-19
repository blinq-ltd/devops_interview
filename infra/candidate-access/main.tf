################################################################################
# gleb (IAM user) -> candidate (IAM role, assumed)
#
# gleb gets only sts:AssumeRole on the "candidate" role plus a long-lived
# access key (needed since he's a human running terraform from his own
# machine, not a federated/OIDC workload). All actual infra permissions live
# on the "candidate" role, scoped to exactly what `terraform apply`/`destroy`
# needs for devops_interview/infra (workstation + eks), generated from the
# real plan JSON via iam-policy-autopilot - see ../../README.md.
################################################################################

# tfsec recommends group-level policies over user-attached ones for
# maintainability at scale; this is a single disposable candidate user with
# exactly one minimal permission (assume-role only), so a group adds
# indirection without benefit here.
#tfsec:ignore:aws-iam-no-user-attached-policies
resource "aws_iam_user" "candidate" {
  name = var.candidate_user_name
}

resource "aws_iam_access_key" "candidate" {
  user = aws_iam_user.candidate.name
}

data "aws_iam_policy_document" "candidate_role_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.candidate.arn]
    }
  }
}

resource "aws_iam_role" "candidate" {
  name                 = var.candidate_role_name
  assume_role_policy   = data.aws_iam_policy_document.candidate_role_assume.json
  max_session_duration = 14400 # 4h - covers the full 2h interview plus setup/buffer
}

data "aws_iam_policy_document" "gleb_assume_candidate" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.candidate.arn]
  }
}

resource "aws_iam_user_policy" "gleb_assume_candidate" {
  name   = "assume-candidate-role"
  user   = aws_iam_user.candidate.name
  policy = data.aws_iam_policy_document.gleb_assume_candidate.json
}

resource "aws_iam_role_policy" "candidate_ec2_eks" {
  name   = "ec2-eks"
  role   = aws_iam_role.candidate.id
  policy = file("${path.module}/policy-ec2-eks.json")
}

resource "aws_iam_role_policy" "candidate_iam_kms_logs" {
  name   = "iam-kms-logs"
  role   = aws_iam_role.candidate.id
  policy = file("${path.module}/policy-iam-kms-logs.json")
}
