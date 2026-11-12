data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "mysql" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.mysql_instance_type
  subnet_id              = var.database_subnet_id
  vpc_security_group_ids = [var.mysql_sg_id]
  iam_instance_profile   = var.instance_profile_name

  user_data = templatefile("${path.module}/user-data/mysql.sh", {
    mysql_database     = var.mysql_database
    mysql_user         = var.mysql_user
    mysql_password_b64 = base64encode(var.mysql_password)
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.project_name}-mysql"
    Role = "Database"
  }
}

resource "aws_security_group" "backup" {
  name_prefix = "${var.project_name}-backup-"
  description = "MySQL backup host: outbound only to MySQL and AWS APIs"
  vpc_id      = var.vpc_id

  egress {
    description     = "MySQL connections to the database instance"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.mysql_sg_id]
  }

  egress {
    description = "HTTPS for package installation, S3 and SNS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP for Ubuntu package repositories"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS resolution through the VPC resolver"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.project_name}-backup-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "mysql_from_backup" {
  type                     = "ingress"
  description              = "MySQL connections from the backup instance"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = var.mysql_sg_id
  source_security_group_id = aws_security_group.backup.id
}

resource "aws_instance" "backup" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.backup_instance_type
  subnet_id              = var.database_subnet_id
  vpc_security_group_ids = [aws_security_group.backup.id]
  iam_instance_profile   = var.instance_profile_name

  user_data = templatefile("${path.module}/user-data/backup.sh", {
    aws_region           = var.aws_region
    backup_bucket_name   = var.backup_bucket_name
    backup_sns_topic_arn = var.backup_sns_topic_arn
    backup_schedule      = var.backup_schedule
    backup_script_b64    = filebase64("${path.module}/scripts/backup_mysql.sh")
    mysql_private_ip     = aws_instance.mysql.private_ip
    mysql_database       = var.mysql_database
    mysql_user           = var.mysql_user
    mysql_password_b64   = base64encode(var.mysql_password)
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.project_name}-mysql-backup"
    Role = "Backup"
  }
}

resource "aws_instance" "backend_a" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.backend_instance_type
  subnet_id              = var.backend_subnet_a_id
  vpc_security_group_ids = [var.backend_a_sg_id]
  iam_instance_profile   = var.instance_profile_name

  user_data = templatefile("${path.module}/user-data/backend.sh", {
    aws_region         = var.aws_region
    backend_image_uri  = var.backend_image_uri
    backend_port       = var.backend_port
    mysql_private_ip   = aws_instance.mysql.private_ip
    mysql_database     = var.mysql_database
    mysql_user         = var.mysql_user
    mysql_password_b64 = base64encode(var.mysql_password)
    jwt_secret_b64     = base64encode(var.jwt_secret)
    rabbitmq_host      = "host.docker.internal"
    install_rabbitmq   = "true"
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.project_name}-backend-a"
    Role = "Backend"
    Pair = "A"
  }
}

resource "aws_instance" "backend_b" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.backend_instance_type
  subnet_id              = var.backend_subnet_b_id
  vpc_security_group_ids = [var.backend_b_sg_id]
  iam_instance_profile   = var.instance_profile_name

  user_data = templatefile("${path.module}/user-data/backend.sh", {
    aws_region         = var.aws_region
    backend_image_uri  = var.backend_image_uri
    backend_port       = var.backend_port
    mysql_private_ip   = aws_instance.mysql.private_ip
    mysql_database     = var.mysql_database
    mysql_user         = var.mysql_user
    mysql_password_b64 = base64encode(var.mysql_password)
    jwt_secret_b64     = base64encode(var.jwt_secret)
    rabbitmq_host      = aws_instance.backend_a.private_ip
    install_rabbitmq   = "false"
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.project_name}-backend-b"
    Role = "Backend"
    Pair = "B"
  }
}

resource "aws_instance" "frontend_a" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.frontend_instance_type
  subnet_id                   = var.public_subnet_a_id
  vpc_security_group_ids      = [var.frontend_a_sg_id]
  associate_public_ip_address = true
  iam_instance_profile        = var.instance_profile_name

  user_data = templatefile("${path.module}/user-data/frontend.sh", {
    aws_region         = var.aws_region
    frontend_image_uri = var.frontend_image_uri
    backend_private_ip = aws_instance.backend_a.private_ip
    frontend_port      = var.frontend_port
    backend_port       = var.backend_port
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.project_name}-frontend-a"
    Role = "Frontend"
    Pair = "A"
  }
}

resource "aws_instance" "frontend_b" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.frontend_instance_type
  subnet_id                   = var.public_subnet_b_id
  vpc_security_group_ids      = [var.frontend_b_sg_id]
  associate_public_ip_address = true
  iam_instance_profile        = var.instance_profile_name

  user_data = templatefile("${path.module}/user-data/frontend.sh", {
    aws_region         = var.aws_region
    frontend_image_uri = var.frontend_image_uri
    backend_private_ip = aws_instance.backend_b.private_ip
    frontend_port      = var.frontend_port
    backend_port       = var.backend_port
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.project_name}-frontend-b"
    Role = "Frontend"
    Pair = "B"
  }
}
