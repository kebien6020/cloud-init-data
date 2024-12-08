variable "playbook" {
  default = "nginx-docker"
}

variable "volume_size" {
  default = 10
}

locals {
  ports = {
    nginx-docker = {
      http  = { port = 80, protocol = "tcp" }
      https = { port = 443, protocol = "tcp" }
    }
    vpn-l2tp = {
      vpn1 = { port = 500, protocol = "udp" }
      vpn2 = { port = 4500, protocol = "udp" }
      vpn3 = { port = 1701, protocol = "udp" }
    }
    vpn-wireguard = {
      vpn = { port = 51820, protocol = "udp" }
    }
  }[var.playbook]

  os_details = {
    al23 = {
      ami  = data.aws_ami.al23_latest.id
      user = "ec2-user"
    }
    ubuntu = {
      ami  = data.aws_ami.ubuntu_24.id
      user = "ubuntu"
    }
  }

  os = {
    nginx-docker  = local.os_details.al23
    vpn-l2tp      = local.os_details.ubuntu
    vpn-wireguard = local.os_details.ubuntu
  }[var.playbook]
}

resource "aws_instance" "main" {
  ami                         = local.os.ami
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.main.key_name

  root_block_device {
    volume_size = var.volume_size
  }

  user_data = <<-EOT
    #cloud-config
    packages:
      - git
      - ansible
    package_update: true
    package_upgrade: true
    runcmd:
      - mkdir -p /run/init
      - ansible-pull -U https://github.com/kebien6020/cloud-init-data.git -d /run/init -vvv ansible/${var.playbook}/playbook.yml
  EOT

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_key_pair" "main" {
  key_name   = "cloud-init-data-main"
  public_key = file("pub_key.pub")
}

output "public_ip" {
  value = aws_instance.main.public_ip
}

output "instance_id" {
  value = aws_instance.main.id
}

output "ssh_command" {
  value = "ssh ${local.os.user}@${aws_instance.main.public_ip}"
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

data "aws_ami" "ubuntu_24" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
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

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.app.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.app.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "service_ports" {
  for_each = local.ports

  security_group_id = aws_security_group.app.id
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = "0.0.0.0/0"
}
