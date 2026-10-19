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
  default = "gleb"
}

variable "candidate_role_name" {
  type    = string
  default = "candidate"
}
