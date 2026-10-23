# This policy used to live on an IAM role assumed by the candidate
# workstation EC2 instance (and later, directly by the candidate IAM user).
# The role is now decommissioned - the candidate user holds this policy
# (and cluster-admin, via infra/eks's access entry) directly on its own base
# identity, so no role/instance-profile/assume-role plumbing is needed at
# all. ECR/RDS are scoped by the `${var.name_prefix}-*` naming convention
# (devops-interview-*); the EKS cluster itself is named via
# var.eks_cluster_name ("interview") since infra/eks doesn't use the
# devops-interview-* prefix for the cluster name.

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

  # eks:ListClusters has no resource-level ARN support (AWS requires
  # Resource "*" for it, same as eks:DescribeClusterVersions) - it was
  # previously (ineffectively) included in the scoped statement above, which
  # silently never granted it. Discovered live via a candidate's AccessDenied.
  statement {
    sid       = "EksListClustersUnscoped"
    actions   = ["eks:ListClusters"]
    resources = ["*"]
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

# Attached directly to the candidate IAM user (infra/candidate-access) - see
# that module's candidate_workstation_policy attachment.
resource "aws_iam_policy" "workstation_candidate" {
  name   = "${var.name_prefix}-candidate-scoped-access-standalone"
  policy = data.aws_iam_policy_document.workstation_candidate.json
}
