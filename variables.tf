variable "aws_region" {
  description = "AWS region in which the infrastructure will be provisioned."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project identifier used in resource names and tags."
  type        = string
  default     = "doces-com-amor"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$", var.project_name))
    error_message = "project_name must contain 3 to 40 lowercase letters, numbers, or hyphens, and cannot start or end with a hyphen."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_a_cidr" {
  description = "CIDR block for public subnet A."
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_b_cidr" {
  description = "CIDR block for public subnet B."
  type        = string
  default     = "10.0.2.0/24"
}

variable "backend_subnet_a_cidr" {
  description = "CIDR block for backend subnet A."
  type        = string
  default     = "10.0.3.0/24"
}

variable "backend_subnet_b_cidr" {
  description = "CIDR block for backend subnet B."
  type        = string
  default     = "10.0.4.0/24"
}

variable "database_subnet_cidr" {
  description = "CIDR block for the private MySQL subnet."
  type        = string
  default     = "10.0.5.0/24"
}

variable "frontend_instance_type" {
  description = "EC2 instance type used by both frontend instances."
  type        = string
  default     = "t3.micro"
}

variable "backend_instance_type" {
  description = "EC2 instance type used by both backend instances."
  type        = string
  default     = "t3.micro"
}

variable "mysql_instance_type" {
  description = "EC2 instance type used by the MySQL instance."
  type        = string
  default     = "t3.micro"
}

variable "frontend_port" {
  description = "TCP port exposed by each frontend to the ALB."
  type        = number
  default     = 80
}

variable "backend_port" {
  description = "TCP port exposed by each backend to its paired frontend."
  type        = number
  default     = 8080
}

variable "backend_image_uri" {
  description = "Complete ECR URI and immutable tag of the backend image."
  type        = string
}

variable "frontend_image_uri" {
  description = "Complete ECR URI and immutable tag of the frontend image."
  type        = string
}

variable "google_calendar_secret_arn" {
  description = "Optional Secrets Manager ARN whose SecretString is the Google Calendar service-account JSON."
  type        = string
  default     = null
  nullable    = true
}

variable "google_calendar_id" {
  description = "Google Calendar identifier used by the backend."
  type        = string
  default     = "3db8bb13db53a3d6b5ce7c6c43795907d1d478f0ff226f066d11acc5c56b06f8@group.calendar.google.com"
}

variable "create_ec2_instance_profile" {
  description = "Create an IAM instance profile that allows EC2 instances to pull from ECR."
  type        = bool
  default     = true
}

variable "ec2_instance_profile_name" {
  description = "Existing instance profile used when IAM creation is restricted."
  type        = string
  default     = null
  nullable    = true
}

variable "mysql_database" {
  description = "Initial application database created in MySQL."
  type        = string
  default     = "doces_com_amor"

  validation {
    condition     = can(regex("^[A-Za-z0-9_]+$", var.mysql_database))
    error_message = "mysql_database may contain only letters, numbers, and underscores."
  }
}

variable "mysql_user" {
  description = "Application database user created in MySQL."
  type        = string
  default     = "admin"

  validation {
    condition     = can(regex("^[A-Za-z0-9_]+$", var.mysql_user))
    error_message = "mysql_user may contain only letters, numbers, and underscores."
  }
}

variable "mysql_password" {
  description = "Password for the MySQL application user. Supplied outside version control."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mysql_password) >= 12
    error_message = "mysql_password must contain at least 12 characters."
  }
}

variable "alb_certificate_arn" {
  description = "Optional ACM certificate ARN. When set, an HTTPS listener is created on port 443."
  type        = string
  default     = null
  nullable    = true
}

variable "alarm_email" {
  description = "Optional email address subscribed to the SNS alarm topic. Confirmation is required."
  type        = string
  default     = null
  nullable    = true
}
