output "candidate_role_arn" {
  value = aws_iam_role.candidate.arn
}

output "gleb_access_key_id" {
  value = aws_iam_access_key.candidate.id
}

output "gleb_secret_access_key" {
  value     = aws_iam_access_key.candidate.secret
  sensitive = true
}

output "aws_cli_profile_snippet" {
  description = "Append to ~/.aws/config and ~/.aws/credentials to let the candidate run terraform via the 'candidate' role and kubectl via the workstation role"
  value       = <<-EOT
    # ~/.aws/credentials
    [candidate-base]
    aws_access_key_id = ${aws_iam_access_key.candidate.id}
    aws_secret_access_key = <terraform output -raw gleb_secret_access_key>

    # ~/.aws/config
    [profile candidate-terraform]
    role_arn = ${aws_iam_role.candidate.arn}
    source_profile = candidate-base
    region = ${var.aws_region}

    [profile candidate-cluster]
    role_arn = ${var.workstation_role_arn}
    source_profile = candidate-base
    region = ${var.aws_region}

    # terraform plan/apply on infra/workstation or infra/eks:
    #   AWS_PROFILE=candidate-terraform terraform plan
    # kubectl / docker / direct cluster access:
    #   AWS_PROFILE=candidate-cluster aws eks update-kubeconfig --name interview --region ${var.aws_region}
  EOT
}
