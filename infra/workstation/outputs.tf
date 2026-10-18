output "workstation_public_ip" {
  description = "Elastic IP of the candidate workstation"
  value       = aws_eip.workstation.public_ip
}

output "candidate_ssh_config" {
  description = "SSH config block to give the candidate (pair with the private half of candidate_ssh_public_key)"
  value       = <<-EOT
    Host blinq-interview
        HostName ${aws_eip.workstation.public_ip}
        User candidate
        IdentityFile ~/.ssh/blinq-interview
  EOT
}

output "workstation_iam_role_arn" {
  description = "IAM role attached to the workstation (reference this when creating EKS access entries later)"
  value       = aws_iam_role.workstation.arn
}

output "workstation_internal_security_group_id" {
  description = "Attach this SG as an allowed ingress source on future EKS/Aurora/Kafka/observability security groups"
  value       = aws_security_group.workstation_internal.id
}

output "workstation_instance_id" {
  value = aws_instance.workstation.id
}
