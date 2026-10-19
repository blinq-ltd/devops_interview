terraform {
  required_version = ">= 1.14.0, < 2.0.0"

  backend "s3" {
    bucket = "terraform-states-382163918348"
    key    = "devops-interview/candidate-access/terraform.tfstate"
    region = "us-east-1"

    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
