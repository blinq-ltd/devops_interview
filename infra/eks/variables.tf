variable "aws_region" {
  description = "AWS region for the interview lab"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used to provision the lab (interviewer's own access, not the candidate's)"
  type        = string
  default     = "blinq-interviews"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "interview"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.36"
}

variable "resource_tags" {
  description = "Tags applied to all taggable resources"
  type        = map(string)
  default = {
    Project   = "devops-interview"
    Component = "eks"
    ManagedBy = "terraform"
  }
}

################################################################################
# VPC / networking
################################################################################

# NOTE: the original ask was 100.15.8.0/16, which is not a valid network
# address for a /16 (host bits must be zero). Corrected to 100.15.0.0/20
# per interviewer confirmation (see devops_interview/README.md).
variable "vpc_cidr" {
  description = "CIDR block for the EKS VPC"
  type        = string
  default     = "100.15.0.0/20"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ (NAT gateway + future ALB)"
  type        = list(string)
  default     = ["100.15.0.0/24", "100.15.1.0/24", "100.15.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ (node group, cluster ENIs)"
  type        = list(string)
  default     = ["100.15.4.0/24", "100.15.5.0/24", "100.15.6.0/24"]
}

variable "availability_zones" {
  description = "AZs to spread the public/private subnets across (must match the order of *_subnet_cidrs)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway for all private subnets (cost-efficient; not cross-AZ HA). Recommended for this disposable interview lab."
  type        = bool
  default     = true
}

################################################################################
# Cluster endpoint access
################################################################################

variable "cluster_endpoint_private_access" {
  description = "Enable the private EKS API endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable the public EKS API endpoint, restricted to cluster_endpoint_public_access_cidrs. Candidates connect directly from their own machines this way instead of through the (disabled) SSH workstation."
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint when cluster_endpoint_public_access = true. Scope tightly to the current candidate's public IP/32 (plus the interviewer's own) before each interview, and tighten it back down afterward."
  type        = list(string)
  default     = []
}

variable "create_autoscaling_slr" {
  description = "Whether to create the account-global AWSServiceRoleForAutoScaling service-linked role. True for the first EKS cluster in a fresh account; false if it already exists."
  type        = bool
  default     = true
}

################################################################################
# Node group
################################################################################

variable "node_group_map" {
  description = "EKS managed node group definitions (terraform-aws-modules/eks/aws eks_managed_node_groups schema)"
  type        = any
  default = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      capacity_type  = "ON_DEMAND"
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      disk_size      = 30
      labels         = {}
      taints         = {}
      metadata_options = {
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }
    }
  }
}

################################################################################
# Access
################################################################################

variable "candidate_user_arn" {
  description = "ARN of the candidate IAM user (infra/candidate-access's aws_iam_user.candidate). Granted AmazonEKSClusterAdminPolicy directly, so kubectl works off the base identity without needing to assume the workstation role."
  type        = string
  default     = ""
}

variable "cluster_admins" {
  description = "IAM principal ARNs granted AmazonEKSClusterAdminPolicy via EKS access entries (in addition to the Terraform-applying identity, which gets admin automatically)"
  type        = list(string)
  default     = []
}

################################################################################
# VPC peering to the workstation's VPC (infra/workstation)
################################################################################

variable "enable_vpc_peering" {
  description = "Create the VPC peering connection + routes + cluster SG ingress that let the workstation reach the private EKS API. On/off switch for infra/eks/modules/vpc_peering."
  type        = bool
  default     = true
}

variable "workstation_vpc_id" {
  description = "VPC ID of the workstation (infra/workstation default VPC). Required when enable_vpc_peering = true. Get it with: aws ec2 describe-vpcs --filters Name=isDefault,Values=true"
  type        = string
  default     = ""
}

variable "workstation_vpc_cidr" {
  description = "CIDR of the workstation's VPC. Required when enable_vpc_peering = true."
  type        = string
  default     = ""
}

variable "workstation_security_group_id" {
  description = "workstation_internal security group ID from infra/workstation (terraform output workstation_internal_security_group_id). The EKS cluster SG allows ingress 443 only from this SG, so only the workstation can reach the private API. Required when enable_vpc_peering = true."
  type        = string
  default     = ""
}
