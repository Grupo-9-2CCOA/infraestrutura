variable "aws_region" {
  description = "AWS region used by the ECR repositories."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used by the ECR repositories."
  type        = string
  default     = "doces-com-amor"
}
