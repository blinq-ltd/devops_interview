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
  description = "Append to ~/.aws/config and ~/.aws/credentials to let gleb run terraform via the candidate role"
  value       = <<-EOT
    # ~/.aws/credentials
    [gleb-base]
    aws_access_key_id = ${aws_iam_access_key.candidate.id}
    aws_secret_access_key = <terraform output -raw gleb_secret_access_key>

    # ~/.aws/config
    [profile gleb]
    role_arn = ${aws_iam_role.candidate.arn}
    source_profile = gleb-base
    region = ${var.aws_region}

    # then: AWS_PROFILE=gleb terraform plan / apply
  EOT
}
