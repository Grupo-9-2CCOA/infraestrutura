resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  bucket_prefix = substr(var.project_name, 0, 40)
  buckets = {
    bronze = "Raw data"
    silver = "Cleaned and standardized data"
    gold   = "Analytics-ready data"
  }
}

resource "aws_s3_bucket" "data" {
  for_each = local.buckets

  bucket        = "${local.bucket_prefix}-${each.key}-${random_id.bucket_suffix.hex}"
  force_destroy = false

  tags = {
    Name        = "${var.project_name}-${each.key}"
    DataLayer   = title(each.key)
    Description = each.value
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  for_each = aws_s3_bucket.data

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  for_each = aws_s3_bucket.data

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

