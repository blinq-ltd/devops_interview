provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "devops-interview"
      Component = "candidate-access"
      ManagedBy = "terraform"
      Temporary = "true"
    }
  }
}

data "aws_caller_identity" "current" {}
