output "frontend_a_instance_id" {
  description = "ID of Frontend A."
  value       = aws_instance.frontend_a.id
}

output "frontend_b_instance_id" {
  description = "ID of Frontend B."
  value       = aws_instance.frontend_b.id
}

output "backend_a_instance_id" {
  description = "ID of Backend A."
  value       = aws_instance.backend_a.id
}

output "backend_b_instance_id" {
  description = "ID of Backend B."
  value       = aws_instance.backend_b.id
}

output "mysql_instance_id" {
  description = "ID of the MySQL instance."
  value       = aws_instance.mysql.id
}

output "mysql_private_ip" {
  description = "Private IP of the MySQL instance."
  value       = aws_instance.mysql.private_ip
}

output "instance_ids" {
  description = "Map of logical instance names to EC2 instance IDs."
  value = {
    frontend_a = aws_instance.frontend_a.id
    frontend_b = aws_instance.frontend_b.id
    backend_a  = aws_instance.backend_a.id
    backend_b  = aws_instance.backend_b.id
    mysql      = aws_instance.mysql.id
  }
}

