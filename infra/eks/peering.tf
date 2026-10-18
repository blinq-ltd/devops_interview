module "vpc_peering" {
  count  = var.enable_vpc_peering ? 1 : 0
  source = "./modules/vpc_peering"

  cluster_name  = var.cluster_name
  resource_tags = var.resource_tags

  eks_vpc_id                    = module.vpc.vpc_id
  eks_vpc_cidr                  = var.vpc_cidr
  eks_private_route_table_ids   = module.vpc.private_route_table_ids
  eks_cluster_security_group_id = module.eks.cluster_security_group_id

  workstation_vpc_id            = var.workstation_vpc_id
  workstation_vpc_cidr          = var.workstation_vpc_cidr
  workstation_security_group_id = var.workstation_security_group_id
}
