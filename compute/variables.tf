variable "project_name" {
  description = "Project identifier used in resource names."
  type        = string
}

variable "public_subnet_a_id" {
  description = "ID of public subnet A."
  type        = string
}

variable "public_subnet_b_id" {
  description = "ID of public subnet B."
  type        = string
}

variable "backend_subnet_a_id" {
  description = "ID of backend subnet A."
  type        = string
}

variable "backend_subnet_b_id" {
  description = "ID of backend subnet B."
  type        = string
}

variable "database_subnet_id" {
  description = "ID of the private database subnet."
  type        = string
}

variable "frontend_a_sg_id" {
  description = "Security group ID for Frontend A."
  type        = string
}

variable "frontend_b_sg_id" {
  description = "Security group ID for Frontend B."
  type        = string
}

variable "backend_a_sg_id" {
  description = "Security group ID for Backend A."
  type        = string
}

variable "backend_b_sg_id" {
  description = "Security group ID for Backend B."
  type        = string
}

variable "mysql_sg_id" {
  description = "Security group ID for MySQL."
  type        = string
}

variable "frontend_instance_type" {
  description = "EC2 instance type for frontends."
  type        = string
}

variable "backend_instance_type" {
  description = "EC2 instance type for backends."
  type        = string
}

variable "mysql_instance_type" {
  description = "EC2 instance type for MySQL."
  type        = string
}

variable "frontend_port" {
  description = "Port served by the frontend web server."
  type        = number
}

variable "backend_port" {
  description = "Port served by the backend application."
  type        = number
}

variable "aws_region" {
  description = "AWS region containing the ECR repositories."
  type        = string
}

variable "backend_image_uri" {
  description = "Complete backend image URI."
  type        = string
}

variable "frontend_image_uri" {
  description = "Complete frontend image URI."
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile that permits ECR image pulls."
  type        = string
}

variable "jwt_secret" {
  description = "JWT signing key passed to the backend containers."
  type        = string
  sensitive   = true
}

variable "google_calendar_id" {
  description = "Google Calendar identifier used by the backend."
  type        = string
}

variable "google_secret_arn" {
  description = "Optional Secrets Manager ARN containing Google service-account JSON."
  type        = string
  default     = null
  nullable    = true
}

variable "mysql_database" {
  description = "Initial MySQL database name."
  type        = string
}

variable "mysql_user" {
  description = "MySQL application username."
  type        = string
}

variable "mysql_password" {
  description = "MySQL application password."
  type        = string
  sensitive   = true
}
