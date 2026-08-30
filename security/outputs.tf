output "alb_sg_id" {
  description = "ID of the ALB security group."
  value       = aws_security_group.alb.id
}

output "frontend_a_sg_id" {
  description = "ID of Frontend A security group."
  value       = aws_security_group.frontend_a.id
}

output "frontend_b_sg_id" {
  description = "ID of Frontend B security group."
  value       = aws_security_group.frontend_b.id
}

output "backend_a_sg_id" {
  description = "ID of Backend A security group."
  value       = aws_security_group.backend_a.id
}

output "backend_b_sg_id" {
  description = "ID of Backend B security group."
  value       = aws_security_group.backend_b.id
}

output "mysql_sg_id" {
  description = "ID of the MySQL security group."
  value       = aws_security_group.mysql.id
}
