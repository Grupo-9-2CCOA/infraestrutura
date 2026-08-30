variable "project_name" {
  description = "Project identifier used in resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC in which the target group is created."
  type        = string
}

variable "public_subnet_ids" {
  description = "Two public subnet IDs used by the internet-facing ALB."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) == 2
    error_message = "Exactly two public subnet IDs are required."
  }
}

variable "alb_security_group" {
  description = "Security group ID assigned to the ALB."
  type        = string
}

variable "frontend_port" {
  description = "Port on which frontend targets serve HTTP."
  type        = number
}

variable "frontend_a_id" {
  description = "EC2 instance ID for Frontend A."
  type        = string
}

variable "frontend_b_id" {
  description = "EC2 instance ID for Frontend B."
  type        = string
}

variable "alb_certificate_arn" {
  description = "Optional ACM certificate ARN used by the HTTPS listener."
  type        = string
  default     = null
  nullable    = true
}

