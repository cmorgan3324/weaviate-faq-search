data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default" {
  id = data.aws_subnets.default_subnets.ids[0]
}

resource "aws_security_group" "weaviate_sg" {
  name        = "weaviate-sg"
  description = "allow inbound http (8080) for Weaviate"
  vpc_id      = data.aws_vpc.default.id


 ingress {
   description = "Weaviate API (8080) from Streamlit"
   from_port   = 8080
   to_port     = 8080
   protocol    = "tcp"
   security_groups = [aws_security_group.streamlit_sg.id] 
}


  ingress {
    description = "ssh from my ip"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["97.133.199.209/32"]
  }


  egress {
    description = "allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "weaviate-sg"
  }
}

# Weaviate ec2: pulls from s3 & runs the Weaviate docker container
resource "aws_instance" "weaviate_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.weaviate_instance_type
  iam_instance_profile        = aws_iam_instance_profile.weaviate_instance_profile.name
  vpc_security_group_ids      = [aws_security_group.weaviate_sg.id]
  associate_public_ip_address = true
  key_name                    = "weaviate-key-pair"

  subnet_id = data.aws_subnet.default.id

  tags = {
    Name = "weaviate-server"
  }

   user_data = <<-EOF
    #!/bin/bash
    set -eux

    # 1️⃣ Install Docker & AWS CLI v2 (curl comes pre-installed)
    yum update -y
    amazon-linux-extras install -y docker
    yum install -y docker
    systemctl enable docker
    systemctl start docker

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install

    # 2️⃣ Host-side loader script (boot-setup.sh)
    cat > /usr/local/bin/boot-setup.sh << 'BOOT'
    #!/bin/bash
    set -e

    # Fetch latest CSV from S3 (ignore errors)
    aws s3 cp s3://${var.faq_csv_bucket_name}/faqs.csv /tmp/faqs.csv || true

    # Create FAQ schema if missing
    curl -X POST http://localhost:8080/v1/schema \
      -H 'Content-Type: application/json' \
      -d @/tmp/faq_schema.json || true

    # Batch ingest CSV
    curl -X POST "http://localhost:8080/v1/batch/objects?batchSize=16&class=FAQ&vectorizer=text2vec-openai" \
      -H 'Content-Type: text/csv' \
      --data-binary @/tmp/faqs.csv || true
    BOOT
    chmod +x /usr/local/bin/boot-setup.sh

    # 3️⃣ Write the systemd unit (weaviate.service)
    cat > /etc/systemd/system/weaviate.service << 'SERVICE'
    [Unit]
    Description=Weaviate Vector DB
    After=network-online.target docker.service
    Wants=network-online.target docker.service

    [Service]
    Type=oneshot
    RemainAfterExit=yes

    # Remove any old container
    ExecStartPre=/bin/bash -lc 'docker rm -f weaviate || true'

    # Pull & run with healthchecks, then invoke host loader
    ExecStart=/bin/bash -lc '\
      docker pull semitechnologies/weaviate:latest && \
      docker run -d \
        --name weaviate \
        --restart unless-stopped \
        --health-cmd="curl -f http://localhost:8080/v1/.well-known/ready || exit 1" \
        --health-interval=30s \
        --health-retries=3 \
        --health-start-period=10s \
        -p 8080:8080 \
        -e QUERY_DEFAULTS_LIMIT=20 \
        -e AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED="true" \
        -e PERSISTENCE_DATA_PATH="/var/lib/weaviate" \
        -e ENABLE_MODULES="text2vec-openai" \
        -e DEFAULT_VECTORIZER_MODULE="text2vec-openai" \
        -e OPENAI_APIKEY="${var.openai_api_key}" \
        -e S3_BUCKET_NAME="${var.faq_csv_bucket_name}" \
        semitechnologies/weaviate:latest && \
       /usr/local/bin/boot-setup.sh'
    ExecStop=/bin/bash -lc 'docker stop weaviate || true'

    [Install]
    WantedBy=multi-user.target
    SERVICE

    # 4️⃣ Enable & start on boot
    systemctl daemon-reload
    systemctl enable --now weaviate.service
  EOF
}

# find the latest amazon linux 2 AMI (can also use ubuntu)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
