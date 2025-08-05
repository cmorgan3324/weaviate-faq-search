output "faq_csv_bucket_name" {
  value = aws_s3_bucket.faq_csv_bucket.bucket
}

output "faq_csv_bucket_arn" {
  value = aws_s3_bucket.faq_csv_bucket.arn
}

output "streamlit_public_ip" {
  description = "public ip of the streamlit/docker ec2 instance"
  value       = aws_instance.streamlit_server.public_ip
}

output "streamlit_url" {
  description = "public url for streamlit app"
  value       = "http://${aws_instance.streamlit_server.public_ip}:8501"
}

output "weaviate_public_ip" {
  description = "public ip of the weaviate ec2 instance"
  value       = aws_instance.weaviate_server.public_ip
}

output "weaviate_url" {
  description = "Public url for weaviate instance"
  value       = "http://${aws_instance.weaviate_server.public_ip}:8080"
}
