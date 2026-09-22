data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_key_pair" "this" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key
}

resource "aws_security_group" "this" {
  name        = "${var.project_name}-sg"
  description = "SSH + API Flask + HTTPS nginx"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "HTTP (gunicorn directo, para health checks)"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS nginx to gunicorn"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

resource "aws_instance" "this" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.this.id]

  user_data = <<-EOF
    #!/bin/bash
    set -xe
    dnf -y install python3 git nginx

    # Certificado autofirmado para HTTPS en EC2 (CN genérico; se regenera tras apply si se desea)
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/nginx/ssl/self.key \
      -out /etc/nginx/ssl/self.crt \
      -subj "/CN=cloud-native"

    # Config nginx: HTTPS → gunicorn:8000
    cat > /etc/nginx/nginx.conf <<'NGINX'
    events { worker_connections 1024; }
    http {
      include       /etc/nginx/mime.types;
      default_type  application/octet-stream;
      sendfile      on;
      keepalive_timeout 65;

      upstream backend { server 127.0.0.1:8000; }

      server {
        listen 80;
        server_name _;
        return 301 https://$host$request_uri;
      }

      server {
        listen 443 ssl http2;
        server_name _;

        ssl_certificate /etc/nginx/ssl/self.crt;
        ssl_certificate_key /etc/nginx/ssl/self.key;
        ssl_protocols TLSv1.2 TLSv1.3;

        location / {
          proxy_pass http://backend;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        }
      }
    }
    NGINX

    systemctl enable --now nginx

    %{if var.repo_url != ""}
    if [ ! -d /home/ec2-user/cloud-native ]; then
      sudo -u ec2-user git clone ${var.repo_url} /home/ec2-user/cloud-native
    fi
    %{endif}
  EOF

  tags = {
    Name = "${var.project_name}-ec2"
  }
}

resource "aws_eip" "this" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-eip" }
}

resource "aws_eip_association" "this" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.id
}
