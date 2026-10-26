variable "project_name" {
  description = "Project identifier used in resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda VPC config."
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda."
  type        = string
}

variable "rabbitmq_host" {
  description = "RabbitMQ host (private IP of backend EC2)."
  type        = string
}

variable "rabbitmq_port" {
  description = "RabbitMQ port."
  type        = number
  default     = 5672
}

variable "rabbitmq_username" {
  description = "RabbitMQ username."
  type        = string
  default     = "guest"
}

variable "rabbitmq_password" {
  description = "RabbitMQ password."
  type        = string
  default     = "guest"
  sensitive   = true
}

variable "rabbitmq_queue" {
  description = "RabbitMQ queue name."
  type        = string
  default     = "calendar.events.queue"
}

variable "google_calendar_id" {
  description = "Google Calendar ID."
  type        = string
  default     = ""
}

variable "google_calendar_credentials_file" {
  description = "Optional path to the Google service-account JSON. When set, Terraform stores it in Secrets Manager so the Lambda can start without a manual put-secret-value."
  type        = string
  default     = null
  nullable    = true
}

variable "poll_schedule_expression" {
  description = "EventBridge schedule used to drain the RabbitMQ queue."
  type        = string
  default     = "rate(1 minute)"
}

variable "existing_lambda_role_arn" {
  description = "Use an existing IAM role for the Lambda instead of creating one. Required in accounts that deny iam:CreateRole (for example AWS Academy)."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}
