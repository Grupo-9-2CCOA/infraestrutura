locals {
  alarm_actions = [aws_sns_topic.alarms.arn]

  ec2_widgets = [
    for instance_name, instance_id in var.ec2_instance_ids : {
      type   = "metric"
      width  = 12
      height = 6
      properties = {
        title   = "EC2 ${replace(title(instance_name), "_", " ")}"
        region  = var.aws_region
        view    = "timeSeries"
        stacked = false
        period  = 300
        stat    = "Average"
        metrics = [
          ["AWS/EC2", "CPUUtilization", "InstanceId", instance_id],
          [".", "StatusCheckFailed", ".", "."]
        ]
      }
    }
  ]

  alb_widgets = [{
    type   = "metric"
    width  = 12
    height = 6
    properties = {
      title   = "Application Load Balancer"
      region  = var.aws_region
      view    = "timeSeries"
      stacked = false
      period  = 300
      stat    = "Sum"
      metrics = [
        ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix],
        ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Maximum" }],
        ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]
      ]
    }
  }]

  s3_widgets = [
    for layer, bucket_name in var.bucket_names : {
      type   = "metric"
      width  = 8
      height = 6
      properties = {
        title  = "S3 ${title(layer)}"
        region = var.aws_region
        view   = "timeSeries"
        period = 86400
        stat   = "Average"
        metrics = [
          ["AWS/S3", "BucketSizeBytes", "BucketName", bucket_name, "StorageType", "StandardStorage"]
        ]
      }
    }
  ]
}

resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-infrastructure-alarms"

  tags = {
    Name = "${var.project_name}-infrastructure-alarms"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email == null ? 0 : 1

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  for_each = var.ec2_instance_ids

  alarm_name          = "${var.project_name}-${each.key}-high-cpu"
  alarm_description   = "CPU utilization is at least 80 percent for ${each.key}."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  dimensions = {
    InstanceId = each.value
  }

  tags = {
    Name = "${var.project_name}-${each.key}-high-cpu"
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check" {
  for_each = var.ec2_instance_ids

  alarm_name          = "${var.project_name}-${each.key}-status-check"
  alarm_description   = "An EC2 status check failed for ${each.key}."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  dimensions = {
    InstanceId = each.value
  }

  tags = {
    Name = "${var.project_name}-${each.key}-status-check"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-alb-unhealthy-hosts"
  alarm_description   = "One or more frontend targets are unhealthy."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  tags = {
    Name = "${var.project_name}-alb-unhealthy-hosts"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-alb-5xx"
  alarm_description   = "The ALB returned at least five HTTP 5xx responses in five minutes."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = {
    Name = "${var.project_name}-alb-5xx"
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-infrastructure"
  dashboard_body = jsonencode({
    widgets = concat(local.ec2_widgets, local.alb_widgets, local.s3_widgets)
  })
}

