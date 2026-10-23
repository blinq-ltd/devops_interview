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
  description = "Append to ~/.aws/config and ~/.aws/credentials. kubectl/docker/ECR work directly off the base profile (no role assumption); only Terraform (scenario 6) needs the separate role-assumption profile."
  value       = <<-EOT
    # ~/.aws/credentials
    [candidate]
    aws_access_key_id = ${aws_iam_access_key.candidate.id}
    aws_secret_access_key = <terraform output -raw gleb_secret_access_key>
    region = ${var.aws_region}

    # ~/.aws/config
    [profile candidate-terraform]
    role_arn = ${aws_iam_role.candidate.arn}
    source_profile = candidate
    region = ${var.aws_region}

    # kubectl / docker / ECR / direct cluster access (base identity, no role assumption):
    #   AWS_PROFILE=candidate aws eks update-kubeconfig --name interview --region ${var.aws_region}
    # terraform plan/apply on infra/workstation or infra/eks (scenario 6):
    #   AWS_PROFILE=candidate-terraform terraform plan
  EOT
}
