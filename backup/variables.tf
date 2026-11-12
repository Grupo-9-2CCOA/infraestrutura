variable "project_name" {
  description = "Project identifier used in resource names."
  type        = string
}

variable "backup_bucket_name" {
  description = "Existing S3 bucket used for MySQL backups. When empty, a dedicated bucket is created."
  type        = string
  default     = ""
}

variable "backup_bucket_force_destroy" {
  description = "Allow Terraform to delete the backup bucket even when it contains objects."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to keep MySQL backups in S3 before expiring them."
  type        = number
  default     = 30

  validation {
    condition     = var.backup_retention_days > 0
    error_message = "backup_retention_days must be greater than zero."
  }
}

variable "backup_alert_email" {
  description = "Optional administrator email subscribed to the backup SNS topic."
  type        = string
  default     = null
  nullable    = true
}

variable "create_iam_policy" {
  description = "Create the IAM policy that allows uploading backups and publishing SNS notifications."
  type        = bool
  default     = true
}
