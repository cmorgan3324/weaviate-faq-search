variable "openai_api_key" {
  type        = string
  description = "openai api key (text2vec-openai module will read this)."
  sensitive   = true
}

variable "faq_csv_bucket_name" {
  type        = string
  description = "name of faq csv bucket"
}

variable "weaviate_instance_type" {
  type        = string
  default     = "t3.medium"
  description = "ec2 instance type to run Weaviate"
}