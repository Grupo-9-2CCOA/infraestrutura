resource "aws_lb" "main" {
  name               = substr("${var.project_name}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "frontends" {
  name     = substr("${var.project_name}-frontends", 0, 32)
  port     = var.frontend_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-399"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-frontends-tg"
  }
}

resource "aws_lb_target_group_attachment" "frontend_a" {
  target_group_arn = aws_lb_target_group.frontends.arn
  target_id        = var.frontend_a_id
  port             = var.frontend_port
}

resource "aws_lb_target_group_attachment" "frontend_b" {
  target_group_arn = aws_lb_target_group.frontends.arn
  target_id        = var.frontend_b_id
  port             = var.frontend_port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontends.arn
  }
}

resource "aws_lb_listener" "https" {
  count = var.alb_certificate_arn == null ? 0 : 1

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontends.arn
  }
}

