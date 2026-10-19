# ECR repo for the candidate's app image (scenario 1). Named with the
# devops-interview-* prefix to match infra/workstation's existing IAM
# scoping for ECR push/pull (see infra/workstation/iam.tf).
resource "aws_ecr_repository" "api" {
  name                 = "devops-interview-api"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.eks.arn
  }

  tags = var.resource_tags
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images after 7 days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = { type = "expire" }
    }]
  })
}

# Scenario 4's synthetic request generator (interview/prereq/4/generator) -
# interviewer-owned, never built/pushed by the candidate.
resource "aws_ecr_repository" "generator" {
  name                 = "devops-interview-generator"
  image_tag_mutability = "IMMUTABLE" # iterate with versioned tags (v1, v2, ...), not by overwriting one tag

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.eks.arn
  }

  tags = var.resource_tags
}

resource "aws_ecr_lifecycle_policy" "generator" {
  repository = aws_ecr_repository.generator.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images after 7 days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = { type = "expire" }
    }]
  })
}
