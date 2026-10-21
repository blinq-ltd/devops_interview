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
  description = "Candidates run this locally (with AWS_PROFILE set to the candidate-cluster profile from infra/candidate-access's aws_cli_profile_snippet output) to configure kubectl against the CIDR-restricted public endpoint."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "vpc_peering_connection_id" {
  value = var.enable_vpc_peering ? module.vpc_peering[0].peering_connection_id : null
}
