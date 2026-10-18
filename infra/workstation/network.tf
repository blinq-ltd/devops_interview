# Uses the account's default VPC. This is a disposable interview account;
# the EKS/Aurora/Kafka modules built later should land in this same VPC so
# the workstation's "internal services" security group can reach them
# without extra peering.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Pick a single subnet deterministically (lowest subnet ID) for the workstation.
locals {
  workstation_subnet_id = sort(data.aws_subnets.default_public.ids)[0]
}

resource "aws_security_group" "workstation_ssh" {
  name        = "${var.name_prefix}-workstation-ssh"
  description = "SSH access to the candidate workstation"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from approved IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-workstation-ssh"
  }
}

# Attach this SG to future private lab resources (EKS nodes/control plane
# endpoint, Aurora, Kafka brokers, Grafana stack) so the workstation can
# reach them. It carries no ingress of its own here; the ingress rules below
# are added to the workstation's egress-reachable peer SG at resource-create
# time by referencing `aws_security_group.workstation_internal.id` as a
# source in those modules' security groups.
resource "aws_security_group" "workstation_internal" {
  name        = "${var.name_prefix}-workstation-internal"
  description = "Identity SG for the candidate workstation; referenced as an allowed source by private lab services (EKS, Aurora, Kafka, observability)"
  vpc_id      = data.aws_vpc.default.id

  egress {
    description = "Reach private lab services"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-workstation-internal"
  }
}
