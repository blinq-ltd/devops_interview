# The candidate's review task: "this Terraform change bundles two things -
# explain exactly what will change, and revise the configuration to avoid
# an unintended replacement."
#
# 1. HARMLESS: adds a CostCenter tag (resource_tags) - shows as an update
#    across every tagged resource, no replacement, safe to apply.
# 2. DISRUPTIVE: capacity_type ON_DEMAND -> SPOT. The EKS CreateNodegroup
#    API does not support changing capacity_type on an existing node
#    group, so this forces a full node-group REPLACEMENT (destroy then
#    create) - the pods currently running on it get evicted/rescheduled,
#    not a rolling update. Verified via `terraform plan` - see
#    interview/prereq/6/saved-plan.txt.
#
# Correct candidate answer separates these: apply the tag change alone (or
# via its own PR), and either (a) don't make the capacity_type change at
# all without a maintenance window and a scale-up-first/drain sequence, or
# (b) achieve a spot-capacity goal a non-disruptive way instead - e.g. add
# a SECOND node group with capacity_type=SPOT alongside the existing
# on-demand one, drain workloads onto it gradually, rather than converting
# the existing one in place.
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
  CostCenter = "platform-eng" # <- harmless addition
}

node_group_map = {
  default = {
    ami_type       = "AL2023_x86_64_STANDARD"
    capacity_type  = "SPOT" # <- was ON_DEMAND; forces node group replacement
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
