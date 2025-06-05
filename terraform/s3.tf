resource "aws_s3_bucket" "faq_csv_bucket" {
  bucket = "weaviate-faq-csv-v24"
  force_destroy = true
  tags = {
    Name        = "weaviate-faq-csv-bucket"
    Environment = "dev"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "faq_csv_encryption" {
  bucket = aws_s3_bucket.faq_csv_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "faq_csv_versioning" {
  bucket = aws_s3_bucket.faq_csv_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ownership controls
resource "aws_s3_bucket_ownership_controls" "faq_csv_bucket" {
  bucket = aws_s3_bucket.faq_csv_bucket.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

# private access block config (block public reads)
resource "aws_s3_bucket_public_access_block" "faq_csv_bucket" {
  bucket = aws_s3_bucket.faq_csv_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# to set acl to private
resource "aws_s3_bucket_acl" "faq_csv_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.faq_csv_bucket,
    aws_s3_bucket_public_access_block.faq_csv_bucket,
  ]

  bucket = aws_s3_bucket.faq_csv_bucket.id
  acl    = "private"
}