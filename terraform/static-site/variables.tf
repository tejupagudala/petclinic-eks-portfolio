variable "aws_region" {
  description = "Region for S3/Route53 resources"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Root/apex domain"
  type        = string
  # e.g. devops-portfolio.online
}

variable "bucket_name" {
  description = "Globally-unique S3 bucket name for site content"
  type        = string
}