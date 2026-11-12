output "bucket_name" {
  description = "S3 bucket that stores the MySQL backups."
  value       = local.bucket_name
}

output "bucket_arn" {
  description = "ARN of the S3 bucket that stores the MySQL backups."
  value       = local.bucket_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic used for backup notifications."
  value       = aws_sns_topic.backup.arn
}

output "iam_policy_arn" {
  description = "ARN of the backup IAM policy, or null when IAM creation is disabled."
  value       = var.create_iam_policy ? aws_iam_policy.backup[0].arn : null
}
