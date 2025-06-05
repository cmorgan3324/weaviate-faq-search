# create an iam role that ec2 can assume
resource "aws_iam_role" "streamlit_ec2_role" {
  name = "streamlit-ec2-role"
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
  policy = <<EOF
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


# attach the managed ecr read-only policy to that role, so ec2 can pull docker images
resource "aws_iam_role_policy_attachment" "streamlit_ecr_readonly" {
  role       = aws_iam_role.streamlit_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "streamlit_attach_ssm" {
  role       = aws_iam_role.streamlit_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# instance profile that ties this role to the Streamlit EC2
resource "aws_iam_instance_profile" "streamlit_instance_profile" {
  name = "streamlit-instance-profile"
  role = aws_iam_role.streamlit_ec2_role.name
}

# Security Group allowing port 8501 (Streamlit) from your IP
resource "aws_security_group" "streamlit_sg" {
  name        = "streamlit-sg"
  description = "Allow inbound 8501 for Streamlit"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Streamlit UI (port 8501) from my IP"
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = ["97.133.246.77/32"]
  }

    ingress {
    description = "Streamlit UI (port 8501) from anywhere"
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["97.133.246.77/32"]
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
  vpc_security_group_ids      = [aws_security_group.streamlit_sg.id]  # Or use weaviate_sg.id if reusing
  key_name                    = "weaviate-key-pair"
  iam_instance_profile        = aws_iam_instance_profile.streamlit_instance_profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    # 1) Update & install Docker
    yum update -y
    amazon-linux-extras install docker -y
    service docker start
    usermod -a -G docker ec2-user

    # 2) Authenticate to ECR
    aws ecr get-login-password --region us-east-1 | \
      docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

    # 3) Pull the latest image
    docker pull 123456789012.dkr.ecr.us-east-1.amazonaws.com/faq-streamlit:latest

    # 4) Run the container
    docker run -d --restart unless-stopped \
      -p 8501:8501 \
      123456789012.dkr.ecr.us-east-1.amazonaws.com/faq-streamlit:latest
  EOF

  tags = {
    Name = "streamlit-server"
  }
}