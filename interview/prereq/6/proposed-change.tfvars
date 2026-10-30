cluster_admins = [
  "arn:aws:iam::382163918348:user/tapan_halani",
]

candidate_user_arn = "arn:aws:iam::382163918348:user/candidate"

enable_vpc_peering = false

cluster_endpoint_public_access = true
cluster_endpoint_public_access_cidrs = [
  "27.60.16.223/32", # interviewer (tapan) - current IP as of 2026-10-30 (IP keeps rotating)
]

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
