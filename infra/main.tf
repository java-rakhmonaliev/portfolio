terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─── Variables ────────────────────────────────────────────────
variable "aws_region" { default = "eu-central-1" }
variable "db_password" { sensitive = true }
variable "secret_key" { sensitive = true }

locals {
  name = "portfolio"
}

# ─── Key Pair ─────────────────────────────────────────────────
resource "aws_key_pair" "portfolio" {
  key_name   = "portfolio-key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

# ─── Security Group ───────────────────────────────────────────
resource "aws_security_group" "portfolio" {
  name        = "${local.name}-sg"
  description = "Allow HTTP, HTTPS, SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-sg" }
}

# ─── EC2 ──────────────────────────────────────────────────────
resource "aws_instance" "portfolio" {
  ami                    = "ami-0faab6bdbac9486fb" # Ubuntu 24.04 eu-central-1
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.portfolio.id]
  key_name               = aws_key_pair.portfolio.key_name

  user_data = templatefile("${path.module}/user_data.sh", {
    secret_key  = var.secret_key
    db_password = var.db_password
    db_host     = aws_db_instance.portfolio.address
  })

  tags = { Name = local.name }

  depends_on = [aws_db_instance.portfolio]
}

# ─── RDS PostgreSQL ───────────────────────────────────────────
resource "aws_db_instance" "portfolio" {
  identifier        = "${local.name}-db"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "portfolio"
  username = "postgres"
  password = var.db_password

  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = false

  vpc_security_group_ids = [aws_security_group.portfolio.id]

  tags = { Name = "${local.name}-db" }
}

# ─── Elastic IP ───────────────────────────────────────────────
resource "aws_eip" "portfolio" {
  instance = aws_instance.portfolio.id
  domain   = "vpc"
  tags     = { Name = local.name }
}

# ─── Outputs ──────────────────────────────────────────────────
output "public_ip" {
  value = aws_eip.portfolio.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.portfolio.address
}
