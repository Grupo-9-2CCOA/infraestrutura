output "alb_dns_name" {
  description = "Public DNS name of the ALB."
  value       = aws_lb.main.dns_name
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix used by CloudWatch metric dimensions."
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix used by CloudWatch metric dimensions."
  value       = aws_lb_target_group.frontends.arn_suffix
}

