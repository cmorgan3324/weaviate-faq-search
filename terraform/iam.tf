# iam role trusted by ec2 so that instance can assume
resource "aws_iam_role" "weaviate_ec2_role" {
  name = "weaviate-ec2-role"

  assume_role_policy = <<EOF
  {
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  }
EOF
}

# iam policy: allow ListBucket + GetObject on the faq csv bucket
resource "aws_iam_policy" "weaviate_s3_access" {
  name        = "weaviate-s3-access"
  description = "allow Weaviate ec2 to read faqs from s3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.faq_csv_bucket.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.faq_csv_bucket.arn}/*"
      }
    ]
  })
}

# attach policy to the role
resource "aws_iam_role_policy_attachment" "attach_weaviate_s3" {
  role       = aws_iam_role.weaviate_ec2_role.name
  policy_arn = aws_iam_policy.weaviate_s3_access.arn
}

# create instance profile for role (for ec2)
resource "aws_iam_instance_profile" "weaviate_instance_profile" {
  name = "weaviate-instance-profile"
  role = aws_iam_role.weaviate_ec2_role.name
}

# for ssm session manager
resource "aws_iam_role_policy_attachment" "attach_ssm_core" {
  role       = aws_iam_role.weaviate_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}