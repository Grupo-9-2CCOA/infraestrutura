variable "project_name" {
  description = "Project identifier used in monitoring resource names."
  type        = string
}

variable "aws_region" {
  description = "AWS region used by dashboard widgets."
  type        = string
}

variable "ec2_instance_ids" {
  description = "Map of logical instance names to EC2 instance IDs."
  type        = map(string)
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch dimensions."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix for CloudWatch dimensions."
  type        = string
}

variable "bucket_names" {
  description = "Map of S3 data layers to bucket names."
  type        = map(string)
}

variable "alarm_email" {
  description = "Optional email address subscribed to the SNS topic."
  type        = string
  default     = null
  nullable    = true
}

