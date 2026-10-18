locals {
  eks_managed_node_groups = {
    for key, pool in var.node_group_map : key => merge(pool, {
      subnet_ids                 = module.vpc.private_subnets
      create_launch_template     = true
      iam_role_attach_cni_policy = true
      enable_monitoring          = true
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = pool.disk_size
            volume_type           = "gp3"
            encrypted             = true
            kms_key_id            = aws_kms_key.ebs.arn
            delete_on_termination = true
          }
        }
      }
      tags = var.resource_tags
    })
  }

  # Cluster admins = explicit var.cluster_admins plus the workstation's own
  # IAM role, so the workstation (and anyone who SSHes into it) has full
  # kubectl/admin access once network reachability exists via VPC peering.
  cluster_admin_principals = concat(
    var.cluster_admins,
    var.workstation_iam_role_arn != "" ? [var.workstation_iam_role_arn] : [],
  )

  access_entries = {
    for idx, arn in local.cluster_admin_principals : "admin-${idx}" => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
}

# Both ignores below are raised against resources generated INSIDE the
# downloaded module, so they must be suppressed at this module call site
# (tfsec requires ignore comments to be immediately adjacent, hence no prose
# between the two directives):
#   - AVD-AWS-0130: launch template IMDS token. False positive -
#     metadata_options.http_tokens = "required" is set via
#     var.node_group_map and verified present in the rendered plan; tfsec's
#     static analysis can't trace an `any`-typed variable through merge().
#   - AVD-AWS-0104: node egress_all. Accepted risk - see the justification
#     comment on the egress_all block in node_security_group_additional_rules
#     below.
#tfsec:ignore:aws-ec2-enforce-launch-config-http-token-imds
#tfsec:ignore:aws-ec2-no-public-egress-sgr
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_private_access = var.cluster_endpoint_private_access
  endpoint_public_access  = var.cluster_endpoint_public_access

  encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true

  enabled_log_types                      = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 7

  addons = {
    vpc-cni = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
    }
  }

  eks_managed_node_groups = local.eks_managed_node_groups

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    # Accepted risk, same reasoning as infra/workstation (AVD-AWS-0104):
    # nodes need broad egress for image pulls (ECR/Docker Hub), AWS API
    # calls, and DNS, and later phases of this lab (ArgoCD git sync, Kafka
    # clients, observability exporters) will need ports that aren't known
    # yet. Unlike the workstation, pod-level egress needs here are
    # heterogeneous and still evolving, so pre-guessing a port allowlist
    # risks silently breaking a later scenario. Revisit with NetworkPolicies
    # once the app/addon set is fixed.
    egress_all = {
      description = "Node all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  access_entries = local.access_entries

  tags = var.resource_tags
}
