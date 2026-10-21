# IAM role attached to the workstation instance. This is the role the
# CANDIDATE effectively operates under (via the instance profile) during the
# live session, so it is kept least-privilege. ECR/RDS are scoped by the
# `${var.name_prefix}-*` naming convention (devops-interview-*); the EKS
# cluster itself is named via var.eks_cluster_name ("interview") since
# infra/eks doesn't use the devops-interview-* prefix for the cluster name.
#
# NOTE: scenario 6 (Terraform drift/maintenance exercise) needs the candidate
# to run `terraform plan`/`apply` against the EKS nodegroup. The exact
# EKS/EC2/IAM write permissions that requires can only be scoped once that
# module exists, so a placeholder statement is marked TODO below — revisit
# before the interview.

data "aws_iam_policy_document" "workstation_assume_role" {
  statement {
    sid     = "Ec2InstanceProfile"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }

  # Lets the candidate IAM user (infra/candidate-access) assume this role
  # directly for local kubectl/docker access, now that the candidate
  # connects straight to the CIDR-restricted public EKS endpoint instead of
  # SSHing into a workstation running under this role's instance profile.
  dynamic "statement" {
    for_each = length(var.candidate_user_arns) > 0 ? [1] : []
    content {
      sid     = "DirectCandidateAccess"
      actions = ["sts:AssumeRole"]
      principals {
        type        = "AWS"
        identifiers = var.candidate_user_arns
      }
    }
  }
}

resource "aws_iam_role" "workstation" {
  name               = "${var.name_prefix}-workstation-candidate-role"
  assume_role_policy = data.aws_iam_policy_document.workstation_assume_role.json
}

data "aws_iam_policy_document" "workstation_candidate" {
  # Identity / general diagnostics
  statement {
    sid       = "CallerIdentity"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  statement {
    sid = "ReadOnlyNetworkDiagnostics"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeRouteTables",
    ]
    resources = ["*"]
  }

  # ECR: push/pull limited to this lab's repositories
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrReadWriteScoped"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.name_prefix}-*",
    ]
  }

  # EKS: describe/list + kubeconfig generation, scoped to lab clusters
  statement {
    sid = "EksDescribeScoped"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:DescribeNodegroup",
      "eks:ListNodegroups",
      "eks:ListUpdates",
      "eks:DescribeUpdate",
      "eks:AccessKubernetesApi",
    ]
    resources = [
      "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster_name}",
      "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:nodegroup/${var.eks_cluster_name}/*/*",
    ]
  }

  # RDS: describe only; actual DB auth happens via a lab-issued DB role/password, not IAM.
  # rds:Describe* actions do not support resource-level ARNs (AWS requires
  # Resource: "*" for them), so access is scoped via the ResourceTag
  # condition below instead - this is the correct/only available control.
  #tfsec:ignore:aws-iam-no-policy-wildcards
  statement {
    sid = "RdsDescribeScoped"
    actions = [
      "rds:DescribeDBInstances",
      "rds:DescribeDBClusters",
      "rds:DescribeDBSubnetGroups",
      "rds:DescribeDBClusterEndpoints",
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/Project"
      values   = ["devops-interview"]
    }
  }

  # TODO(scenario-6): add scoped EKS nodegroup / EC2 tagging / autoscaling
  # write permissions once infra/eks is written, limited to the specific
  # nodegroup(s) and tag-change operations rehearsed for the exercise.
}

resource "aws_iam_role_policy" "workstation_candidate" {
  name   = "${var.name_prefix}-candidate-scoped-access"
  role   = aws_iam_role.workstation.id
  policy = data.aws_iam_policy_document.workstation_candidate.json
}

# Standalone copy of the same policy, attachable directly to the candidate
# IAM user (infra/candidate-access) so base-identity API calls (tools that
# don't go through this role's sts:AssumeRole flow) have the same access the
# workstation instance used to have, instead of discovering gaps one
# AccessDenied at a time.
resource "aws_iam_policy" "workstation_candidate" {
  name   = "${var.name_prefix}-candidate-scoped-access-standalone"
  policy = data.aws_iam_policy_document.workstation_candidate.json
}

resource "aws_iam_instance_profile" "workstation" {
  name = "${var.name_prefix}-workstation"
  role = aws_iam_role.workstation.name
}
