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
variable "aws_region"   { default = "eu-central-1" }
variable "db_password"  { sensitive = true }
variable "secret_key"   { sensitive = true }

locals {
  name = "portfolio"
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
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
  key_name               = "portfolio-key"

  user_data = <<-SHELL
    #!/bin/bash
    apt-get update -y
    apt-get install -y python3-pip python3-venv nginx git postgresql-client

    # Clone repo
    git clone https://github.com/java-rakhmonaliev/portfolio.git /app
    cd /app

    # Python env
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt

    # Write .env
    cat > /app/.env << 'ENVEOF'
SECRET_KEY=${var.secret_key}
DEBUG=False
ALLOWED_HOSTS=java-rakhmonaliev.uz,www.java-rakhmonaliev.uz
DB_NAME=portfolio
DB_USER=postgres
DB_PASSWORD=${var.db_password}
DB_HOST=${aws_db_instance.portfolio.address}
DB_PORT=5432
ENVEOF

    # Migrate + collectstatic
    source .venv/bin/activate
    python manage.py migrate
    python manage.py collectstatic --noinput

    # Gunicorn systemd service
    cat > /etc/systemd/system/portfolio.service << 'SVCEOF'
[Unit]
Description=Portfolio Django App
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/app
EnvironmentFile=/app/.env
ExecStart=/app/.venv/bin/gunicorn portfolio.wsgi:application --bind 127.0.0.1:8000 --workers 2
Restart=always

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable portfolio
    systemctl start portfolio

    # Nginx config
    cat > /etc/nginx/sites-available/portfolio << 'NGINXEOF'
server {
    listen 80;
    server_name java-rakhmonaliev.uz www.java-rakhmonaliev.uz;

    location /static/ {
        alias /app/staticfiles/;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
NGINXEOF

    ln -s /etc/nginx/sites-available/portfolio /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t && systemctl restart nginx
  SHELL

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