data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_key_pair" "workstation" {
  count    = var.enable_workstation_instance ? 1 : 0
  key_name = var.ec2_key_pair_name
}

resource "aws_instance" "workstation" {
  count         = var.enable_workstation_instance ? 1 : 0
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = data.aws_key_pair.workstation[0].key_name
  subnet_id     = local.workstation_subnet_id
  vpc_security_group_ids = [
    aws_security_group.workstation_ssh[0].id,
    aws_security_group.workstation_internal[0].id,
    aws_security_group.workstation_dashboards[0].id,
  ]
  iam_instance_profile        = aws_iam_instance_profile.workstation.name
  associate_public_ip_address = true

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    candidate_ssh_public_key = var.candidate_ssh_public_key
    admin_ssh_public_keys    = join("\n", var.admin_ssh_public_keys)
    eks_kubernetes_version   = var.eks_kubernetes_version
    terraform_version        = var.terraform_version
  })
  user_data_replace_on_change = true

  tags = {
    Name = "${var.name_prefix}-workstation"
  }
}

resource "aws_eip" "workstation" {
  count    = var.enable_workstation_instance ? 1 : 0
  instance = aws_instance.workstation[0].id
  domain   = "vpc"

  tags = {
    Name = "${var.name_prefix}-workstation"
  }
}
