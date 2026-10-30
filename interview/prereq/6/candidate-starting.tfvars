# Copy of infra/eks/terraform.tfvars as it stands today - the candidate's
# starting point. Not sensitive (no secrets, just resource identifiers),
# safe to commit so this exercise is reproducible across candidates even
# after the real tfvars (gitignored) has moved on.
#
# NOTE: cluster_endpoint_public_access_cidrs changes before every interview
# (each candidate's IP is added, then removed afterward) - this snapshot
# will drift from the live tfvars on that one field alone. Regenerate
# saved-plan.txt against the real, current tfvars shortly before each
# interview if you want a perfectly clean plan; the CIDR-only diff this
# causes is cosmetic and unrelated to the exercise either way.
cluster_admins = [
  "arn:aws:iam::382163918348:user/tapan_halani",
]

candidate_user_arn = "arn:aws:iam::382163918348:user/candidate"

enable_vpc_peering = false

cluster_endpoint_public_access = true
cluster_endpoint_public_access_cidrs = [
  "27.60.16.223/32", # interviewer (tapan) - current IP as of 2026-10-30 (IP keeps rotating)
]

node_group_map = {
  default = {
    ami_type       = "AL2023_x86_64_STANDARD"
    capacity_type  = "ON_DEMAND"
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
