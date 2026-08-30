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

resource "aws_instance" "backend_a" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.backend_instance_type
  subnet_id              = var.backend_subnet_a_id
  vpc_security_group_ids = [var.backend_a_sg_id]

  user_data = templatefile("${path.module}/user-data/backend.sh", {
    backend_name     = "Backend A"
    backend_port     = var.backend_port
    mysql_private_ip = aws_instance.mysql.private_ip
    mysql_database   = var.mysql_database
    mysql_user       = var.mysql_user
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

  user_data = templatefile("${path.module}/user-data/backend.sh", {
    backend_name     = "Backend B"
    backend_port     = var.backend_port
    mysql_private_ip = aws_instance.mysql.private_ip
    mysql_database   = var.mysql_database
    mysql_user       = var.mysql_user
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

  user_data = templatefile("${path.module}/user-data/frontend.sh", {
    frontend_name      = "Frontend A"
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

  user_data = templatefile("${path.module}/user-data/frontend.sh", {
    frontend_name      = "Frontend B"
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
