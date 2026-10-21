output "workstation_public_ip" {
  description = "Elastic IP of the candidate workstation (null when enable_workstation_instance = false)"
  value       = var.enable_workstation_instance ? aws_eip.workstation[0].public_ip : null
}

locals {
  candidate_ssh_config = <<-EOT
    Host blinq-interview
        HostName ${try(aws_eip.workstation[0].public_ip, "")}
        User candidate
        IdentityFile ~/.ssh/blinq-interview
  EOT
}

output "candidate_ssh_config" {
  description = "SSH config block to give the candidate (pair with the private half of candidate_ssh_public_key). Null when the workstation instance is disabled - candidates connect directly to the CIDR-restricted public EKS endpoint instead (see infra/candidate-access outputs)."
  value       = var.enable_workstation_instance ? local.candidate_ssh_config : null
}

output "workstation_candidate_policy_arn" {
  description = "Standalone copy of the workstation role's scoped policy, for infra/candidate-access to attach directly to the candidate IAM user"
  value       = aws_iam_policy.workstation_candidate.arn
}

output "workstation_iam_role_arn" {
  description = "IAM role (kept regardless of enable_workstation_instance - reference this for EKS access entries and for infra/candidate-access's workstation_role_arn, which lets the candidate user assume it directly)"
  value       = aws_iam_role.workstation.arn
}

output "workstation_internal_security_group_id" {
  description = "Attach this SG as an allowed ingress source on future EKS/Aurora/Kafka/observability security groups (null when enable_workstation_instance = false)"
  value       = var.enable_workstation_instance ? aws_security_group.workstation_internal[0].id : null
}

output "workstation_instance_id" {
  value = var.enable_workstation_instance ? aws_instance.workstation[0].id : null
}
