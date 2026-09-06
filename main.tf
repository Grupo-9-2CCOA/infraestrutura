module "network" {
  source = "./network"

  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  public_subnet_a_cidr  = var.public_subnet_a_cidr
  public_subnet_b_cidr  = var.public_subnet_b_cidr
  backend_subnet_a_cidr = var.backend_subnet_a_cidr
  backend_subnet_b_cidr = var.backend_subnet_b_cidr
  database_subnet_cidr  = var.database_subnet_cidr
}

module "security" {
  source = "./security"

  project_name  = var.project_name
  vpc_id        = module.network.vpc_id
  frontend_port = var.frontend_port
  backend_port  = var.backend_port
}

module "compute" {
  source = "./compute"

  project_name           = var.project_name
  public_subnet_a_id     = module.network.public_subnet_a_id
  public_subnet_b_id     = module.network.public_subnet_b_id
  backend_subnet_a_id    = module.network.backend_subnet_a_id
  backend_subnet_b_id    = module.network.backend_subnet_b_id
  database_subnet_id     = module.network.database_subnet_id
  frontend_a_sg_id       = module.security.frontend_a_sg_id
  frontend_b_sg_id       = module.security.frontend_b_sg_id
  backend_a_sg_id        = module.security.backend_a_sg_id
  backend_b_sg_id        = module.security.backend_b_sg_id
  mysql_sg_id            = module.security.mysql_sg_id
  frontend_instance_type = var.frontend_instance_type
  backend_instance_type  = var.backend_instance_type
  mysql_instance_type    = var.mysql_instance_type
  frontend_port          = var.frontend_port
  backend_port           = var.backend_port
  aws_region             = var.aws_region
  backend_image_uri      = var.backend_image_uri
  frontend_image_uri     = var.frontend_image_uri
  instance_profile_name  = local.ec2_instance_profile_name
  jwt_secret             = random_id.jwt_secret.b64_std
  google_calendar_id     = var.google_calendar_id
  google_secret_arn      = var.google_calendar_secret_arn
  mysql_database         = var.mysql_database
  mysql_user             = var.mysql_user
  mysql_password         = var.mysql_password
}

module "load_balancer" {
  source = "./load-balancer"

  project_name        = var.project_name
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = [module.network.public_subnet_a_id, module.network.public_subnet_b_id]
  alb_security_group  = module.security.alb_sg_id
  frontend_port       = var.frontend_port
  frontend_a_id       = module.compute.frontend_a_instance_id
  frontend_b_id       = module.compute.frontend_b_instance_id
  alb_certificate_arn = var.alb_certificate_arn
}

module "storage" {
  source = "./storage"

  project_name = var.project_name
}

module "observability" {
  source = "./observability"

  project_name            = var.project_name
  aws_region              = var.aws_region
  ec2_instance_ids        = module.compute.instance_ids
  alb_arn_suffix          = module.load_balancer.alb_arn_suffix
  target_group_arn_suffix = module.load_balancer.target_group_arn_suffix
  bucket_names            = module.storage.bucket_names
  alarm_email             = var.alarm_email
}
