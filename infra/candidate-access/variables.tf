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

variable "workstation_candidate_policy_arn" {
  description = "ARN of infra/workstation's standalone candidate policy (output workstation_candidate_policy_arn) - the same permissions the workstation role had, attached directly to the candidate user so base-identity API calls (tools that don't assume a role) work too."
  type        = string
  default     = ""
}
