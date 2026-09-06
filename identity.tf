resource "aws_iam_role" "ec2_ecr" {
  count = var.create_ec2_instance_profile ? 1 : 0

  name = "${var.project_name}-ec2-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_read_only" {
  count = var.create_ec2_instance_profile ? 1 : 0

  role       = aws_iam_role.ec2_ecr[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_ecr" {
  count = var.create_ec2_instance_profile ? 1 : 0

  name = "${var.project_name}-ec2-ecr-profile"
  role = aws_iam_role.ec2_ecr[0].name
}

resource "aws_iam_role_policy" "google_calendar_secret" {
  count = var.create_ec2_instance_profile && var.google_calendar_secret_arn != null ? 1 : 0

  name = "read-google-calendar-secret"
  role = aws_iam_role.ec2_ecr[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.google_calendar_secret_arn
    }]
  })
}

resource "random_id" "jwt_secret" {
  byte_length = 32
}

locals {
  ec2_instance_profile_name = var.create_ec2_instance_profile ? aws_iam_instance_profile.ec2_ecr[0].name : var.ec2_instance_profile_name
}

check "existing_instance_profile_is_configured" {
  assert {
    condition     = var.create_ec2_instance_profile || var.ec2_instance_profile_name != null
    error_message = "ec2_instance_profile_name is required when create_ec2_instance_profile is false."
  }
}
