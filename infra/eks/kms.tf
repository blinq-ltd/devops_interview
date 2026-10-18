################################################################################
# KMS key to encrypt k8s secrets (envelope encryption)
################################################################################
resource "aws_kms_key" "eks" {
  description             = "${var.cluster_name} envelope encryption key for secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = var.resource_tags
}

################################################################################
# KMS key to encrypt EBS volumes attached to EKS managed node groups
################################################################################

# The Auto Scaling service-linked role is account-global and normally created
# on-demand the first time an ASG is provisioned. In a fresh account, creating
# the KMS key before that role exists fails with
# "MalformedPolicyDocumentException: ... invalid principals" because the role
# doesn't exist yet - so it's created explicitly here (var.create_autoscaling_slr).
resource "aws_iam_service_linked_role" "autoscaling" {
  count = var.create_autoscaling_slr ? 1 : 0

  aws_service_name = "autoscaling.amazonaws.com"
  description      = "Default SLR for EC2 Auto Scaling; used by EKS managed node groups to encrypt EBS volumes with a CMK"

  lifecycle {
    ignore_changes = [description, tags, tags_all]
  }
}

data "aws_iam_role" "autoscaling_slr" {
  count = var.create_autoscaling_slr ? 0 : 1
  name  = "AWSServiceRoleForAutoScaling"
}

locals {
  autoscaling_slr_arn = var.create_autoscaling_slr ? aws_iam_service_linked_role.autoscaling[0].arn : data.aws_iam_role.autoscaling_slr[0].arn
}

resource "aws_kms_key" "ebs" {
  description             = "Customer managed key to encrypt EKS managed node group volumes"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.ebs.json

  tags = var.resource_tags
}

data "aws_iam_policy_document" "ebs" {
  statement {
    sid       = "EnableIamUserPermissions"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid = "AllowServiceLinkedRoleAndClusterUseOfTheCmk"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        local.autoscaling_slr_arn,       # ASG managing encrypted node volumes
        module.eks.cluster_iam_role_arn, # cluster / PV controller creating encrypted PVCs
      ]
    }
  }

  statement {
    sid       = "AllowAttachmentOfPersistentResources"
    actions   = ["kms:CreateGrant"]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        local.autoscaling_slr_arn,
        module.eks.cluster_iam_role_arn,
      ]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}
