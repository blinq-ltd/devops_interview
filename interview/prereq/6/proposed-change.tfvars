cluster_admins = [
  "arn:aws:iam::382163918348:user/tapan_halani",
]

workstation_iam_role_arn      = "arn:aws:iam::382163918348:role/devops-interview-workstation-candidate-role"
workstation_vpc_id            = "vpc-0ffe7238cc3af1d54"
workstation_vpc_cidr          = "172.31.0.0/16"
workstation_security_group_id = "sg-093a62edadd1c791b"

resource_tags = {
  Project    = "devops-interview"
  Component  = "eks"
  ManagedBy  = "terraform"
  CostCenter = "platform-eng"
}

node_group_map = {
  default = {
    ami_type       = "AL2023_x86_64_STANDARD"
    capacity_type  = "SPOT"
    instance_types = ["t3.large"]
    min_size       = 1
    max_size       = 3
    desired_size   = 2
    disk_size      = 30
    labels         = {}
    taints         = {}
    metadata_options = {
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
    }
  }
}
