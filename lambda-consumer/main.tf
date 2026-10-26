locals {
  create_role = var.existing_lambda_role_arn == null
  role_arn    = local.create_role ? aws_iam_role.lambda[0].arn : var.existing_lambda_role_arn

  google_credentials = (
    var.google_calendar_credentials_file != null && var.google_calendar_credentials_file != ""
    ? try(file(var.google_calendar_credentials_file), null)
    : null
  )
}

resource "aws_secretsmanager_secret" "google_calendar" {
  name_prefix             = "${var.project_name}-google-calendar-"
  description             = "Google service account JSON for Calendar API"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "google_calendar" {
  count = local.google_credentials == null ? 0 : 1

  secret_id     = aws_secretsmanager_secret.google_calendar.id
  secret_string = local.google_credentials
}

resource "aws_iam_role" "lambda" {
  count = local.create_role ? 1 : 0

  name_prefix = "${var.project_name}-lambda-consumer-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count = local.create_role ? 1 : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_secrets" {
  count = local.create_role ? 1 : 0

  name_prefix = "${var.project_name}-lambda-secrets-"
  role        = aws_iam_role.lambda[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [aws_secretsmanager_secret.google_calendar.arn]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-calendar-consumer"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_lambda_function" "consumer" {
  function_name = "${var.project_name}-calendar-consumer"
  role          = local.role_arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60
  memory_size   = 256

  filename         = "${path.module}/lambda.zip"
  source_code_hash = try(filebase64sha256("${path.module}/lambda.zip"), null)

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      RABBITMQ_HOST      = var.rabbitmq_host
      RABBITMQ_PORT      = tostring(var.rabbitmq_port)
      RABBITMQ_USERNAME  = var.rabbitmq_username
      RABBITMQ_PASSWORD  = var.rabbitmq_password
      RABBITMQ_QUEUE     = var.rabbitmq_queue
      GOOGLE_SECRET_ARN  = aws_secretsmanager_secret.google_calendar.arn
      GOOGLE_CALENDAR_ID = var.google_calendar_id
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_iam_role_policy.lambda_secrets,
    aws_cloudwatch_log_group.lambda,
    aws_secretsmanager_secret_version.google_calendar
  ]

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.project_name}-calendar-consumer-schedule"
  description         = "Periodically drains the calendar events queue"
  schedule_expression = var.poll_schedule_expression
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "calendar-consumer"
  arn       = aws_lambda_function.consumer.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.consumer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
