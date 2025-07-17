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
    description      = "Weaviate api (port 8080) from anywhere"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "ssh from my ip"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["97.133.245.33/32"]
  }
  ingress {
    description = "inbound 8080 from my ip"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["97.133.245.33/32"]
  }

  ingress {
    description = "allow Streamlit port 8501"
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = ["54.173.126.22/32"]
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

  # -------------------------
  # User Data: Install Docker & Start Weaviate
  # -------------------------
  #   user_data = <<-EOF
  #     #!/bin/bash
  #     set -e

  #     # 1) Update system & install Docker
  #     yum update -y
  #     amazon-linux-extras install docker -y
  #     service docker start
  #     usermod -a -G docker ec2-user

  #     # 2) Install AWS CLI v2 (to pull from S3)
  #     curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  #     unzip /tmp/awscliv2.zip -d /tmp
  #     /tmp/aws/install

  #     # 3) Create a directory for Weaviate data persistence
  #     mkdir -p /var/lib/weaviate

  #     # 4) Fetch the FAQ CSV from S3 into /tmp
  #     aws s3 cp s3://${var.faq_csv_bucket_name}/faqs.csv /tmp/faqs.csv

  #     # 5) Launch Weaviate container with OpenAI module enabled
  #     docker run -d \
  #       --name weaviate \
  #       -p 8080:8080 \
  #       -e QUERY_DEFAULTS_LIMIT=20 \
  #       -e AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED="true" \
  #       -e PERSISTENCE_DATA_PATH="/var/lib/weaviate" \
  #       -e DEFAULT_VECTORIZER_MODULE="text2vec-openai" \
  #       -e OPENAI_APIKEY="${var.openai_api_key}" \
  #       -e S3_BUCKET_NAME="${var.faq_csv_bucket_name}" \
  #       semitechnologies/weaviate:latest

  #     # 6) (Optional) Wait a few seconds, then import the CSV into Weaviate
  #     # sleep 15
  #     # curl -X POST "http://localhost:8080/v1/meta" \
  #     #      -H "Content-Type: application/json" \
  #     #      -d '{"action": "import", "filePath": "/tmp/faqs.csv", "batchSize": 16, "sep": ","}'
  #   EOF
  # }

  user_data = <<-EOF
    #cloud-config

    # 1) Update & install packages in one atomic phase
    package_update: true
    packages:
      - amazon-linux-extras
      - docker

    # 2) Drop in our idempotent boot-setup script
    write_files:
      - path: /usr/local/bin/boot-setup.sh
        owner: root:root
        permissions: '0755'
        content: |
          #!/bin/bash
          set -e

          # (Re)fetch the latest CSV
          aws s3 cp s3://${var.faq_csv_bucket_name}/faqs.csv /tmp/faqs.csv || true

          # Create FAQ schema if missing
          docker exec weaviate bash -c "\
            weaviate-client schema get FAQ > /dev/null 2>&1 || \
            curl -X POST http://localhost:8080/v1/schema \
              -H 'Content-Type: application/json' \
              -d @/tmp/faq_schema.json"

          # Batch ingest CSV (won’t duplicate existing objects)
          docker exec weaviate bash -c "\
            curl -X POST \
              'http://localhost:8080/v1/batch/objects?batchSize=16&class=FAQ&vectorizer=text2vec-openai' \
              -H 'Content-Type: text/csv' \
              --data-binary @/tmp/faqs.csv || true"

    # 3) Commands to run on every boot, *after* packages are installed
    runcmd:
      # Enable & start Docker
      - amazon-linux-extras enable docker
      - systemctl enable --now docker

      # Install AWS CLI v2
      - curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
      - unzip /tmp/awscliv2.zip -d /tmp
      - /tmp/aws/install

      # Prepare data directory & fetch CSV
      - mkdir -p /var/lib/weaviate
      - aws s3 cp s3://${var.faq_csv_bucket_name}/faqs.csv /tmp/faqs.csv

      # Launch Weaviate with auto-restart
      - docker run -d \
          --name weaviate \
          --restart unless-stopped \
          -p 8080:8080 \
          -e QUERY_DEFAULTS_LIMIT=20 \
          -e AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED="true" \
          -e PERSISTENCE_DATA_PATH="/var/lib/weaviate" \
          -e ENABLE_MODULES="text2vec-openai" \
          -e DEFAULT_VECTORIZER_MODULE="text2vec-openai" \
          -e OPENAI_APIKEY="${var.openai_api_key}" \
          -e S3_BUCKET_NAME="${var.faq_csv_bucket_name}" \
          semitechnologies/weaviate:latest

      # Run our schema + data ingestion script
      - /usr/local/bin/boot-setup.sh
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
