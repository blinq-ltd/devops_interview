variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  description = "Interviewer's own profile, used to provision gleb's access - not gleb's own credentials"
  type        = string
  default     = "blinq-interviews"
}

variable "candidate_user_name" {
  type    = string
  default = "candidate"
}

variable "candidate_role_name" {
  type    = string
  default = "candidate"
}

variable "workstation_role_arn" {
  description = "ARN of infra/workstation's IAM role (output workstation_iam_role_arn). The candidate user is granted sts:AssumeRole on it directly, for local kubectl access against the CIDR-restricted public EKS endpoint now that the workstation EC2 instance is disabled."
  type        = string
  default     = ""
}
