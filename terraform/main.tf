locals {
  playbook = "nginx-docker"
}

resource "aws_instance" "main" {
  ami                         = data.aws_ami.al23_latest.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true

  user_data = <<-EOT
    #cloud-config
    packages:
      - git
    ansible:
      install_method: distro
      package_name: ansible
      pull:
        url: https://github.com/kebien6020/cloud-init-data.git
        playbook_name: ansible/${local.playbook}/playbook.yml
  EOT

  lifecycle {
    create_before_destroy = true
  }
}

output "public_ip" {
  value = aws_instance.main.public_ip
}

output "instance_id" {
  value = aws_instance.main.id
}

data "aws_ami" "al23_latest" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-minimal-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "public" {
  vpc_id = data.aws_vpc.default.id

  filter {
    name   = "tag:Name"
    values = ["pub-b"]
  }
}

resource "aws_security_group" "app" {
  vpc_id = data.aws_vpc.default.id
  name   = "app-sg"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.app.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.app.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.app.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
