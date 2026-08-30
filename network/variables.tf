variable "project_name" {
  description = "Project identifier used in resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_a_cidr" {
  description = "CIDR block for public subnet A."
  type        = string
}

variable "public_subnet_b_cidr" {
  description = "CIDR block for public subnet B."
  type        = string
}

variable "backend_subnet_a_cidr" {
  description = "CIDR block for backend subnet A."
  type        = string
}

variable "backend_subnet_b_cidr" {
  description = "CIDR block for backend subnet B."
  type        = string
}

variable "database_subnet_cidr" {
  description = "CIDR block for the database subnet."
  type        = string
}

