data "aws_ecr_repository" "backend" {
  name = var.backend_repository_name
}

data "aws_ecr_repository" "frontend" {
  name = var.frontend_repository_name
}

data "aws_ecr_image" "backend" {
  repository_name = data.aws_ecr_repository.backend.name
  most_recent     = true
}

data "aws_ecr_image" "frontend" {
  repository_name = data.aws_ecr_repository.frontend.name
  most_recent     = true
}

locals {
  resolved_backend_image_uri  = try(trimspace(var.backend_image_uri), "") != "" ? var.backend_image_uri : "${data.aws_ecr_repository.backend.repository_url}@${data.aws_ecr_image.backend.image_digest}"
  resolved_frontend_image_uri = try(trimspace(var.frontend_image_uri), "") != "" ? var.frontend_image_uri : "${data.aws_ecr_repository.frontend.repository_url}@${data.aws_ecr_image.frontend.image_digest}"
}
