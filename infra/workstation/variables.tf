variable "aws_region" {
  description = "AWS region for the interview lab"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used to provision the lab (interviewer's own access, not the candidate's)"
  type        = string
  default     = "blinq-interviews"
}

variable "name_prefix" {
  description = "Prefix applied to all resource names/tags for this lab"
  type        = string
  default     = "devops-interview"
}

variable "instance_type" {
  description = "EC2 instance type for the candidate workstation"
  type        = string
  default     = "t3.large"
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 60
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to the workstation (candidate's public IP/32, plus interviewer's own for testing). MUST be updated before the interview."
  type        = list(string)
}

variable "candidate_ssh_public_key" {
  description = "Public half of the temporary SSH keypair handed to the candidate"
  type        = string
}

variable "ec2_key_pair_name" {
  description = "Name of an EC2 key pair already registered in AWS, used as the instance's key_name (default 'ubuntu' user access)"
  type        = string
  default     = "devops-interview-workstation-keypair"
}

variable "admin_ssh_public_keys" {
  description = "Interviewer/admin public keys, authorized on the default 'ubuntu' user (kept separate from the candidate user)"
  type        = list(string)
  default     = []
}

variable "eks_kubernetes_version" {
  description = "EKS Kubernetes version the workstation's kubectl/eksctl should target (informational, used to pick kubectl channel)"
  type        = string
  default     = "1.36"
}

variable "terraform_version" {
  description = "Terraform version to install on the workstation, pinned to match the infra modules"
  type        = string
  default     = "1.14.0"
}

variable "additional_internal_cidrs" {
  description = "Extra CIDR blocks (e.g. the peered infra/eks VPC) the workstation's internal-service egress rules should reach, in addition to the default VPC"
  type        = list(string)
  default     = []
}

variable "internal_service_ports" {
  description = "TCP ports on future private lab services (EKS API, Aurora, Kafka, observability) that the workstation needs to reach"
  type = list(object({
    description = string
    port        = number
  }))
  default = [
    { description = "Kubernetes API (EKS control plane)", port = 443 },
    { description = "PostgreSQL (Aurora)", port = 5432 },
    { description = "Kafka plaintext/internal listener", port = 9092 },
    { description = "Kafka TLS listener", port = 9093 },
    { description = "Kafka external/NodePort listener", port = 9094 },
    { description = "Grafana", port = 3000 },
    { description = "Prometheus/Mimir query", port = 9090 },
    { description = "Loki", port = 3100 },
  ]
}
