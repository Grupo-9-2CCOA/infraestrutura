resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  description = "Public HTTP and HTTPS access to the application load balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "frontend_a" {
  name_prefix = "${var.project_name}-frontend-a-"
  description = "Frontend A accepts application traffic only from the ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Application traffic from ALB"
    from_port       = var.frontend_port
    to_port         = var.frontend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-frontend-a-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "frontend_b" {
  name_prefix = "${var.project_name}-frontend-b-"
  description = "Frontend B accepts application traffic only from the ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Application traffic from ALB"
    from_port       = var.frontend_port
    to_port         = var.frontend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-frontend-b-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "backend_a" {
  name_prefix = "${var.project_name}-backend-a-"
  description = "Backend A accepts application traffic only from Frontend A"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Application traffic from Frontend A"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_a.id]
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-backend-a-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "backend_b" {
  name_prefix = "${var.project_name}-backend-b-"
  description = "Backend B accepts application traffic only from Frontend B"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Application traffic from Frontend B"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_b.id]
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-backend-b-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "mysql" {
  name_prefix = "${var.project_name}-mysql-"
  description = "MySQL accepts database connections only from the two backends"
  vpc_id      = var.vpc_id

  ingress {
    description = "MySQL from paired backends"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [
      aws_security_group.backend_a.id,
      aws_security_group.backend_b.id
    ]
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-mysql-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "lambda_consumer" {
  name_prefix = "${var.project_name}-lambda-consumer-"
  description = "Lambda consumer for RabbitMQ calendar events"
  vpc_id      = var.vpc_id

  egress {
    description     = "AMQP to backend instances"
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_a.id, aws_security_group.backend_b.id]
  }

  egress {
    description = "DNS resolution through the VPC resolver"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "HTTPS to Google APIs and Secrets Manager"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-lambda-consumer-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "backend_a_amqp_from_lambda" {
  type                     = "ingress"
  description              = "AMQP from Lambda consumer"
  from_port                = 5672
  to_port                  = 5672
  protocol                 = "tcp"
  security_group_id        = aws_security_group.backend_a.id
  source_security_group_id = aws_security_group.lambda_consumer.id
}

resource "aws_security_group_rule" "backend_b_amqp_from_lambda" {
  type                     = "ingress"
  description              = "AMQP from Lambda consumer"
  from_port                = 5672
  to_port                  = 5672
  protocol                 = "tcp"
  security_group_id        = aws_security_group.backend_b.id
  source_security_group_id = aws_security_group.lambda_consumer.id
}

resource "aws_security_group_rule" "backend_a_amqp_from_backend_b" {
  type                     = "ingress"
  description              = "AMQP from backend B producer"
  from_port                = 5672
  to_port                  = 5672
  protocol                 = "tcp"
  security_group_id        = aws_security_group.backend_a.id
  source_security_group_id = aws_security_group.backend_b.id
}
