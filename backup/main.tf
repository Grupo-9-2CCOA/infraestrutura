locals {
  create_bucket = var.backup_bucket_name == ""

  bucket_name = local.create_bucket ? aws_s3_bucket.backup[0].bucket : var.backup_bucket_name
  bucket_arn  = local.create_bucket ? aws_s3_bucket.backup[0].arn : "arn:aws:s3:::${var.backup_bucket_name}"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "backup" {
  count = local.create_bucket ? 1 : 0

  bucket        = "${substr(var.project_name, 0, 40)}-mysql-backups-${random_id.bucket_suffix.hex}"
  force_destroy = var.backup_bucket_force_destroy

  tags = {
    Name    = "${var.project_name}-mysql-backups"
    Purpose = "MySQL backups"
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  count = local.create_bucket ? 1 : 0

  bucket                  = aws_s3_bucket.backup[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  count = local.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.backup[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "backup" {
  count = local.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.backup[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  count = local.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.backup[0].id

  rule {
    id     = "expire-old-mysql-backups"
    status = "Enabled"

    filter {}

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

resource "aws_sns_topic" "backup" {
  name = "${var.project_name}-mysql-backup-notifications"

  tags = {
    Name    = "${var.project_name}-mysql-backup-notifications"
    Purpose = "MySQL backup notifications"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count = var.backup_alert_email == null || var.backup_alert_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.backup.arn
  protocol  = "email"
  endpoint  = var.backup_alert_email
}

resource "aws_iam_policy" "backup" {
  count = var.create_iam_policy ? 1 : 0

  name        = "${var.project_name}-mysql-backup-policy"
  description = "Allows the MySQL backup instance to upload dumps to S3 and publish SNS notifications."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "UploadMysqlBackups"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:AbortMultipartUpload"
        ]
        Resource = "${local.bucket_arn}/*"
      },
      {
        Sid      = "PublishBackupNotifications"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.backup.arn
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-mysql-backup-policy"
    Purpose = "MySQL backups"
  }
}
