data "aws_ecr_repository" "backend" {
  name = var.backend_repository_name
}

data "aws_ecr_repository" "frontend" {
  name = var.frontend_repository_name
}

locals {
  backend_image_override  = try(trimspace(var.backend_image_uri), "")
  frontend_image_override = try(trimspace(var.frontend_image_uri), "")
}

data "aws_ecr_image" "backend" {
  count = local.backend_image_override == "" ? 1 : 0

  repository_name = data.aws_ecr_repository.backend.name
  most_recent     = true
}

data "aws_ecr_image" "frontend" {
  count = local.frontend_image_override == "" ? 1 : 0

  repository_name = data.aws_ecr_repository.frontend.name
  most_recent     = true
}

locals {
  resolved_backend_image_uri  = local.backend_image_override != "" ? var.backend_image_uri : "${data.aws_ecr_repository.backend.repository_url}@${data.aws_ecr_image.backend[0].image_digest}"
  resolved_frontend_image_uri = local.frontend_image_override != "" ? var.frontend_image_uri : "${data.aws_ecr_repository.frontend.repository_url}@${data.aws_ecr_image.frontend[0].image_digest}"
}
