output "faq_csv_bucket_name" {
  value = aws_s3_bucket.faq_csv_bucket.bucket
}

output "faq_csv_bucket_arn" {
  value = aws_s3_bucket.faq_csv_bucket.arn
}

output "weaviate_public_ip" {
  description = "public ip of the Weaviate ec2 instance"
  value       = aws_instance.weaviate_server.public_ip
}

output "streamlit_public_ip" {
  description = "public ip of the streamlit/docker ec2 instance"
  value       = aws_instance.streamlit_server.public_ip
}