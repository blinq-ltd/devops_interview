variable "cluster_name" {
  type = string
}

variable "resource_tags" {
  type    = map(string)
  default = {}
}

variable "eks_vpc_id" {
  description = "VPC ID of the EKS cluster (requester side)"
  type        = string
}

variable "eks_vpc_cidr" {
  type = string
}

variable "eks_private_route_table_ids" {
  description = "Route table IDs of the EKS VPC's private subnets"
  type        = list(string)
}

variable "eks_cluster_security_group_id" {
  description = "Security group guarding the EKS API endpoint ENIs (module.eks.cluster_security_group_id)"
  type        = string
}

variable "workstation_vpc_id" {
  description = "VPC ID that hosts the candidate workstation (accepter side)"
  type        = string
}

variable "workstation_vpc_cidr" {
  type = string
}

variable "workstation_security_group_id" {
  description = "The workstation's identity SG (workstation_internal) - the EKS cluster SG allows ingress 443 only from this, so only the workstation can reach the private API"
  type        = string
}
