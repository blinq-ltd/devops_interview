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

################################################################################
# Direct cluster access: the candidate user also assumes infra/workstation's
# IAM role (already granted AmazonEKSClusterAdminPolicy via an EKS access
# entry), so they can run kubectl locally against the CIDR-restricted public
# endpoint without the SSH workstation in the loop.
################################################################################

data "aws_iam_policy_document" "candidate_assume_workstation" {
  count = var.workstation_role_arn != "" ? 1 : 0
  statement {
    actions   = ["sts:AssumeRole"]
    resources = [var.workstation_role_arn]
  }
}

resource "aws_iam_user_policy" "candidate_assume_workstation" {
  count  = var.workstation_role_arn != "" ? 1 : 0
  name   = "assume-workstation-role"
  user   = aws_iam_user.candidate.name
  policy = data.aws_iam_policy_document.candidate_assume_workstation[0].json
}

################################################################################
# A handful of read-only EKS actions that some clients (console, IDE/Toolkit
# plugins) call under the base identity directly, before/without assuming
# any role - eks:DescribeClusterVersions has no resource-level ARN support
# (AWS requires Resource "*" for it), discovered live when a candidate's
# tooling hit AccessDenied on it as arn:...:user/candidate.
################################################################################

data "aws_iam_policy_document" "candidate_eks_readonly_base" {
  statement {
    actions   = ["eks:DescribeClusterVersions"]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "candidate_eks_readonly_base" {
  name   = "eks-readonly-base"
  user   = aws_iam_user.candidate.name
  policy = data.aws_iam_policy_document.candidate_eks_readonly_base.json
}

# Full EKS API access on the base identity, after repeated one-at-a-time
# AccessDenied errors (DescribeClusterVersions, ListClusters, ...) from
# whatever tooling calls AWS directly instead of through an assumed role.
# Kubernetes RBAC (actual kubectl access) is unaffected either way - that
# still depends solely on the EKS access entry for the assumed workstation
# role, not on this IAM policy.
data "aws_iam_policy_document" "candidate_eks_full" {
  statement {
    actions   = ["eks:*"]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "candidate_eks_full" {
  name   = "eks-full-access"
  user   = aws_iam_user.candidate.name
  policy = data.aws_iam_policy_document.candidate_eks_full.json
}

# The same permissions the workstation role had, attached directly to the
# base candidate user - so any client calling AWS APIs under the base
# identity (not through sts:AssumeRole) has the access the workstation
# instance used to provide, instead of surfacing as one-at-a-time
# AccessDenied errors.
resource "aws_iam_user_policy_attachment" "candidate_workstation_policy" {
  count      = var.workstation_candidate_policy_arn != "" ? 1 : 0
  user       = aws_iam_user.candidate.name
  policy_arn = var.workstation_candidate_policy_arn
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
