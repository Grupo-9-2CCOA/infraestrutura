output "lambda_function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.consumer.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.consumer.arn
}

output "google_calendar_secret_arn" {
  description = "ARN of the Secrets Manager secret for Google Calendar credentials."
  value       = aws_secretsmanager_secret.google_calendar.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role."
  value       = local.role_arn
}
