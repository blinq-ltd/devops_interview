# Peers the EKS VPC with the workstation's VPC so the workstation (and only
# the workstation) can reach the EKS cluster's private API endpoint. On/off
# switch lives one level up: the root module only instantiates this module
# when var.enable_vpc_peering = true (see ../peering.tf).

resource "aws_vpc_peering_connection" "this" {
  vpc_id      = var.eks_vpc_id
  peer_vpc_id = var.workstation_vpc_id
  auto_accept = true # same account, same region

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags = merge(var.resource_tags, {
    Name = "${var.cluster_name}-workstation-peering"
  })
}

# EKS side: route the workstation's CIDR into every private subnet's route
# table. Keyed by index (statically known) rather than toset() of the route
# table IDs themselves (unknown until apply on a fresh create, which breaks
# for_each - "Invalid for_each argument").
resource "aws_route" "eks_to_workstation" {
  for_each = { for idx, rt_id in var.eks_private_route_table_ids : tostring(idx) => rt_id }

  route_table_id            = each.value
  destination_cidr_block    = var.workstation_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

# Workstation side: route the EKS VPC's CIDR into the workstation VPC's main
# route table (its only route table - infra/workstation uses the default VPC
# without any custom table).
data "aws_route_table" "workstation_main" {
  vpc_id = var.workstation_vpc_id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

resource "aws_route" "workstation_to_eks" {
  route_table_id            = data.aws_route_table.workstation_main.id
  destination_cidr_block    = var.eks_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

# Only the workstation (by security group membership, not just by being
# somewhere in its VPC) may reach the private API endpoint ENIs.
resource "aws_security_group_rule" "api_from_workstation" {
  description              = "EKS private API from the candidate workstation (via VPC peering)"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.eks_cluster_security_group_id
  source_security_group_id = var.workstation_security_group_id
}
