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

# Single-responsibility: this SG only governs SSH ingress. It carries no
# egress rules of its own (tfsec: aws-ec2-no-public-egress-sgr) - all
# outbound traffic for the instance is governed by workstation_internal's
# scoped egress below, since the instance has both SGs attached.
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

  tags = {
    Name = "${var.name_prefix}-workstation-ssh"
  }
}

# Admin dashboards (ArgoCD/Grafana/Prometheus) reached as
# <workstation-public-ip>:<port> from the interviewer's own browser - the
# workstation runs persistent `kubectl port-forward --address 0.0.0.0`
# systemd services (see user_data.sh.tpl) bridging these ports to the
# in-cluster Services. Scoped to the same trusted IPs as SSH, not the
# whole internet - these are admin-level control planes (ArgoCD especially).
resource "aws_security_group" "workstation_dashboards" {
  name        = "${var.name_prefix}-workstation-dashboards"
  description = "ArgoCD/Grafana/Prometheus UI access from trusted IPs, bridged by local kubectl port-forward"
  vpc_id      = data.aws_vpc.default.id

  dynamic "ingress" {
    for_each = { for p in var.dashboard_ports : p.name => p }
    content {
      description = "${ingress.value.name} UI"
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  tags = {
    Name = "${var.name_prefix}-workstation-dashboards"
  }
}

# Generic internet egress a build/dev workstation genuinely needs: package
# mirrors (apt, Docker Hub, GitHub releases, HashiCorp/Apache mirrors), DNS
# and NTP. A static CIDR allow-list isn't practical here - these endpoints
# span many, frequently-changing IP ranges across providers - so this is
# scoped by PORT instead of by destination, which removes the "all
# protocols/all ports" exposure tfsec flagged while keeping the box able to
# do its job.
locals {
  internet_egress_ports = [
    { description = "HTTPS (package mirrors, AWS/GitHub APIs)", protocol = "tcp", port = 443 },
    { description = "HTTP (apt mirrors)", protocol = "tcp", port = 80 },
    { description = "DNS (tcp)", protocol = "tcp", port = 53 },
    { description = "DNS (udp)", protocol = "udp", port = 53 },
    { description = "NTP", protocol = "udp", port = 123 },
  ]
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

  # Accepted risk: tfsec (AVD-AWS-0104) flags any 0.0.0.0/0 egress regardless
  # of port scope. A build/dev workstation must reach package mirrors
  # (apt, Docker Hub, GitHub releases, HashiCorp/Apache mirrors) that span
  # many, frequently-changing provider IP ranges - a static CIDR allow-list
  # isn't maintainable. Mitigation already applied: scoped to 5 specific
  # ports instead of all protocols/all ports (see the removed "-1" rule this
  # replaced).
  #tfsec:ignore:aws-ec2-no-public-egress-sgr
  dynamic "egress" {
    for_each = { for p in local.internet_egress_ports : "${p.protocol}-${p.port}" => p }
    content {
      description = egress.value.description
      from_port   = egress.value.port
      to_port     = egress.value.port
      protocol    = egress.value.protocol
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "egress" {
    for_each = { for p in var.internal_service_ports : "svc-${p.port}" => p }
    content {
      description = egress.value.description
      from_port   = egress.value.port
      to_port     = egress.value.port
      protocol    = "tcp"
      # default VPC (this box) + the peered EKS/lab VPC, once infra/eks exists
      cidr_blocks = concat([data.aws_vpc.default.cidr_block], var.additional_internal_cidrs)
    }
  }

  tags = {
    Name = "${var.name_prefix}-workstation-internal"
  }
}
