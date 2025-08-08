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
  name        = "rancher-prime-security-group"
  description = "Allow inbound SSH and RKE2 communication"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open SSH to all IPs (adjust as needed)
  }

  ingress {
    from_port   = 9345
    to_port     = 9345
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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

  user_data = <<-EOT
    #!/bin/bash
      "curl -sfL https://get.rke2.io | sh -",
      "systemctl enable rke2-server.service",
      "systemctl start rke2-server.service",
      "sleep 20", # Allow some time for the master node to initialize
      "cat /var/lib/rancher/rke2/server/node-token > /tmp/rke2_token.txt"
    EOT
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

   user_data = <<-EOT
                    #!/bin/bash
                    curl -sfL https://get.rke2.io | sh -
                    systemctl enable rke2-agent.service
                    systemctl start rke2-agent.service
                    echo "RKE2_TOKEN=$(cat /tmp/rke2_token.txt)" >> /etc/rancher/rke2/config.yaml
                    echo "RKE2_SERVER=https://$(aws_instance.rancher_master.public_ip):9345" >> /etc/rancher/rke2/config.yaml
                EOT

  tags = {
    Name = "rancher-prime-worker"
  }

  depends_on = [
    aws_instance.rancher_master
  ]
}

