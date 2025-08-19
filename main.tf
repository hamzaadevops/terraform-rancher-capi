provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

# Create a key pair
resource "tls_private_key" "rancher_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "rancher_key" {
  key_name   = var.key_name
  public_key = tls_private_key.rancher_key.public_key_openssh
}

# Save private key locally
resource "local_file" "private_key" {
  content  = tls_private_key.rancher_key.private_key_pem
  filename = "${path.module}/${var.key_name}.pem"
  file_permission = "0600"
}

resource "aws_security_group" "rancher_sg" {
  name        = var.rancher_sg
  description = "Allow inbound SSH and RKE2 communication"
  vpc_id      = var.vpc_id # <-- replace with your VPC ID

  # SSH Web (public, adjust for your admin IPs)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Public if needed for kubectl from anywhere
  }

  # RKE2 node registration
  ingress {
    from_port   = 9345
    to_port     = 9345
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your VPC/private network
  }

  # etcd client comms (servers only)
  ingress {
    from_port   = 2379
    to_port     = 2381
    protocol    = "tcp"
    cidr_blocks = ["172.31.0.0/16"]
  }

  # Kubelet API (metrics server, monitoring)
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["172.31.0.0/16"]
  }

  # VXLAN (Flannel) — only within cluster
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["172.31.0.0/16"]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rancher-prime-security-group"
  }
}

resource "aws_instance" "rancher_master" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.rancher_key.key_name
  vpc_security_group_ids      = [aws_security_group.rancher_sg.id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true

  root_block_device {
    volume_size = 40    # Size in GB
    volume_type = "gp3"
  }

  tags = {
    Name = "rancher-prime-master"
  }
}

data "aws_instance" "rancher_master" {
  instance_id = aws_instance.rancher_master.id
}

resource "aws_instance" "rancher_worker" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.rancher_key.key_name
  vpc_security_group_ids      = [aws_security_group.rancher_sg.id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true

  root_block_device {
    volume_size = 40    # Size in GB
    volume_type = "gp3"
  }

  tags = {
    Name = "rancher-prime-worker"
  }

  depends_on = [
    aws_instance.rancher_master
  ]
}


resource "aws_instance" "oss_rancher_master" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.rancher_key.key_name
  vpc_security_group_ids      = [aws_security_group.rancher_sg.id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true

  root_block_device {
    volume_size = 40    # Size in GB
    volume_type = "gp3"
  }

  tags = {
    Name = "rancher-oss-master"
  }
}

data "aws_instance" "oss_rancher_master" {
  instance_id = aws_instance.oss_rancher_master.id
}

resource "aws_instance" "oss_rancher_worker" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.rancher_key.key_name
  vpc_security_group_ids      = [aws_security_group.rancher_sg.id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true

  root_block_device {
    volume_size = 40    # Size in GB
    volume_type = "gp3"
  }

  tags = {
    Name = "rancher-oss-worker"
  }

  depends_on = [
    aws_instance.oss_rancher_master
  ]
}

