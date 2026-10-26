output "vpc_id" {
  description = "VPC identifier."
  value       = module.network.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer."
  value       = module.load_balancer.alb_dns_name
}


output "backend_image_uri" {
  description = "Resolved backend container image URI used by EC2."
  value       = local.resolved_backend_image_uri
}

output "frontend_image_uri" {
  description = "Resolved frontend container image URI used by EC2."
  value       = local.resolved_frontend_image_uri
}

output "lambda_consumer_function_name" {
  description = "Name of the Lambda calendar consumer."
  value       = module.lambda_consumer.lambda_function_name
}

output "google_calendar_secret_arn" {
  description = "ARN of Secrets Manager secret for Google Calendar service account."
  value       = module.lambda_consumer.google_calendar_secret_arn
}
