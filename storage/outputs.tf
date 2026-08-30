output "bronze_bucket_name" {
  description = "Name of the Bronze bucket."
  value       = aws_s3_bucket.data["bronze"].bucket
}

output "silver_bucket_name" {
  description = "Name of the Silver bucket."
  value       = aws_s3_bucket.data["silver"].bucket
}

output "gold_bucket_name" {
  description = "Name of the Gold bucket."
  value       = aws_s3_bucket.data["gold"].bucket
}

output "bucket_names" {
  description = "Map of data layer names to S3 bucket names."
  value       = { for layer, bucket in aws_s3_bucket.data : layer => bucket.bucket }
}

