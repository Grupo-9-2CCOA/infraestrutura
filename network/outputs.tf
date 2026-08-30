output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_a_id" {
  description = "ID of public subnet A."
  value       = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  description = "ID of public subnet B."
  value       = aws_subnet.public_b.id
}

output "backend_subnet_a_id" {
  description = "ID of backend subnet A."
  value       = aws_subnet.backend_a.id
}

output "backend_subnet_b_id" {
  description = "ID of backend subnet B."
  value       = aws_subnet.backend_b.id
}

output "database_subnet_id" {
  description = "ID of the private database subnet."
  value       = aws_subnet.database.id
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 Gateway VPC endpoint."
  value       = aws_vpc_endpoint.s3.id
}

