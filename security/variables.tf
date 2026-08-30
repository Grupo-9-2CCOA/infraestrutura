variable "project_name" {
  description = "Project identifier used in resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC in which security groups are created."
  type        = string
}

variable "frontend_port" {
  description = "Frontend application port."
  type        = number
}

variable "backend_port" {
  description = "Backend application port."
  type        = number
}

