# create an iam role that ec2 can assume
resource "aws_iam_role" "streamlit_ec2_role" {
  name               = "streamlit-ec2-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ecr_read_only" {
  name        = "ECRReadOnlyPolicy"
  description = "Allow pulling images from ECR"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_ecr_read" {
  role       = aws_iam_role.streamlit_ec2_role.name
  policy_arn = aws_iam_policy.ecr_read_only.arn
}



resource "aws_iam_role_policy_attachment" "streamlit_attach_ssm" {
  role       = aws_iam_role.streamlit_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# Security Group allowing port 8501 (Streamlit) from your IP
resource "aws_security_group" "streamlit_sg" {
  name        = "streamlit-sg"
  description = "Allow inbound 8501 for Streamlit"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Streamlit UI (port 8501) from anywhere (testing)"
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = ["97.133.199.209/32"]
  }

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["97.133.245.33/32"]
  }

egress {
    description = "Allow outbound to Weaviate (port 8080)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Streamlit ec2 instance
resource "aws_instance" "streamlit_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.medium"
  subnet_id                   = data.aws_subnets.default_subnets.ids[0]
  vpc_security_group_ids      = [aws_security_group.streamlit_sg.id] # Or use weaviate_sg.id if reusing
  key_name                    = "weaviate-key-pair"
  iam_instance_profile        = aws_iam_instance_profile.streamlit_instance_profile.name
  associate_public_ip_address = true

  tags = {
    Name = "streamlit-server"
  }

user_data = <<-EOF
#!/bin/bash
# 1. install Docker & AWS CLI
yum update -y
amazon-linux-extras install -y docker
yum install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

# 2. write the systemd service
cat << 'SERVICE' > /etc/systemd/system/streamlit.service
[Unit]
Description=Streamlit FAQ UI
After=network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Type=oneshot
RemainAfterExit=yes

# login to ECR so pulls will succeed
ExecStartPre=/bin/bash -lc 'aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin 864899872694.dkr.ecr.us-east-1.amazonaws.com'

# pull the latest Streamlit image
ExecStartPre=/usr/bin/docker pull 864899872694.dkr.ecr.us-east-1.amazonaws.com/faq-streamlit:latest

# remove any old container (ignore failure)
ExecStartPre=-/usr/bin/docker rm -f faq-streamlit

# run the container, discovering Weaviate’s private IP
ExecStart=/bin/bash -lc 'WEA_IP=$(aws ec2 describe-instances \
    --region us-east-1 \
    --filters "Name=tag:Name,Values=weaviate-server" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].PrivateIpAddress" \
    --output text) && \
  docker run -d \
    --name faq-streamlit \
    --restart unless-stopped \
    --health-cmd="curl -f http://localhost:8501 || exit 1" \
    --health-interval=30s \
    --health-retries=3 \
    --health-start-period=5s \
    -e WEAVIATE_URL="http://$WEA_IP:8080" \
    -p 0.0.0.0:8501:8501 \
    864899872694.dkr.ecr.us-east-1.amazonaws.com/faq-streamlit:latest'

# stop command
ExecStop=/usr/bin/docker stop faq-streamlit || true

[Install]
WantedBy=multi-user.target
SERVICE

# 3. reload & start the service
systemctl daemon-reload
systemctl enable --now streamlit.service
EOF

#  user_data = <<-EOF
# #!/bin/bash
# # 1. Install Docker & AWS CLI
# yum update -y
# amazon-linux-extras install -y docker
# yum install -y docker
# systemctl enable docker
# systemctl start docker
# usermod -aG docker ec2-user

# curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
# unzip /tmp/awscliv2.zip -d /tmp
# /tmp/aws/install

# # 2. Write the systemd service
# cat << 'SERVICE' > /etc/systemd/system/streamlit.service
# [Unit]
# Description=Streamlit FAQ UI
# After=network-online.target docker.service
# Wants=network-online.target docker.service

# [Service]
# Type=oneshot
# RemainAfterExit=yes

# # Login to ECR so we can pull private images
# ExecStartPre=/bin/bash -lc 'aws ecr get-login-password --region us-east-1 \
#   | docker login --username AWS --password-stdin 864899872694.dkr.ecr.us-east-1.amazonaws.com'


# # Remove any old container
# ExecStartPre=-/usr/bin/docker rm -f faq-streamlit

# # Run the container
# ExecStart=/bin/bash -c 'WEA_IP=$(aws ec2 describe-instances \
#     --region us-east-1 \
#     --filters "Name=tag:Name,Values=weaviate-server" \
#               "Name=instance-state-name,Values=running" \
#     --query "Reservations[0].Instances[0].PrivateIpAddress" \
#     --output text) && \
#   docker run -d \
#     --health-cmd="curl -f http://localhost:8501 || exit 1" \
#     --health-interval=30s \
#     --health-retries=3 \
#     --health-start-period=5s \
#     --name faq-streamlit \
#     --restart unless-stopped \
#     -e WEAVIATE_URL="http://$WEA_IP:8080" \
#     -p 0.0.0.0:8501:8501 \
#     864899872694.dkr.ecr.us-east-1.amazonaws.com/faq-streamlit:latest'
# ExecStop=/usr/bin/docker stop faq-streamlit

# [Install]
# WantedBy=multi-user.target
# SERVICE

# # 3. Reload & start the service
# systemctl daemon-reload
# systemctl enable --now streamlit.service
# EOF
}