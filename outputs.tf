output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "public_subnet_a_id" {
  description = "ID of public subnet A."
  value       = module.network.public_subnet_a_id
}

output "public_subnet_b_id" {
  description = "ID of public subnet B."
  value       = module.network.public_subnet_b_id
}

output "backend_subnet_a_id" {
  description = "ID of backend subnet A."
  value       = module.network.backend_subnet_a_id
}

output "backend_subnet_b_id" {
  description = "ID of backend subnet B."
  value       = module.network.backend_subnet_b_id
}

output "database_subnet_id" {
  description = "ID of the database subnet."
  value       = module.network.database_subnet_id
}

output "frontend_a_instance_id" {
  description = "ID of frontend instance A."
  value       = module.compute.frontend_a_instance_id
}

output "frontend_b_instance_id" {
  description = "ID of frontend instance B."
  value       = module.compute.frontend_b_instance_id
}

output "backend_a_instance_id" {
  description = "ID of backend instance A."
  value       = module.compute.backend_a_instance_id
}

output "backend_b_instance_id" {
  description = "ID of backend instance B."
  value       = module.compute.backend_b_instance_id
}

output "mysql_instance_id" {
  description = "ID of the MySQL instance."
  value       = module.compute.mysql_instance_id
}

output "mysql_private_ip" {
  description = "Private IP address of the MySQL instance."
  value       = module.compute.mysql_private_ip
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = module.load_balancer.alb_dns_name
}

output "bronze_bucket_name" {
  description = "Name of the Bronze data bucket."
  value       = var.enable_data_lake ? module.storage[0].bronze_bucket_name : null
}

output "silver_bucket_name" {
  description = "Name of the Silver data bucket."
  value       = var.enable_data_lake ? module.storage[0].silver_bucket_name : null
}

output "gold_bucket_name" {
  description = "Name of the Gold data bucket."
  value       = var.enable_data_lake ? module.storage[0].gold_bucket_name : null
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic used by CloudWatch alarms."
  value       = module.observability.sns_topic_arn
}

output "ec2_instance_profile_name" {
  description = "Instance profile used by the application EC2 instances."
  value       = local.ec2_instance_profile_name
}

output "selected_backend_image_uri" {
  description = "Backend image automatically selected from ECR or explicitly pinned."
  value       = local.resolved_backend_image_uri
}

output "selected_frontend_image_uri" {
  description = "Frontend image automatically selected from ECR or explicitly pinned."
  value       = local.resolved_frontend_image_uri
}
