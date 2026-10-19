output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "update_kubeconfig_command" {
  description = "Run this ON THE WORKSTATION (not locally - the API is private) to configure kubectl. The workstation's instance profile supplies credentials automatically, so no --profile flag is needed there."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "vpc_peering_connection_id" {
  value = var.enable_vpc_peering ? module.vpc_peering[0].peering_connection_id : null
}
