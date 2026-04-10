##############################################################################
# CloudWatch Alarms — errors and latency monitoring
##############################################################################
locals {
  lambdas = {
    create_item = aws_lambda_function.create_item.function_name
    get_item    = aws_lambda_function.get_item.function_name
    list_items  = aws_lambda_function.list_items.function_name
    delete_item = aws_lambda_function.delete_item.function_name
  }
}

# SNS topic for alarm notifications (optional — only used if email provided)
resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-${var.environment}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.cloudwatch_alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.cloudwatch_alarm_email
}

# Error rate alarm for each Lambda
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = local.lambdas

  alarm_name          = "${each.value}-errors"
  alarm_description   = "Lambda ${each.key} error rate exceeded threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
}

# P99 duration alarm for each Lambda
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = local.lambdas

  alarm_name          = "${each.value}-high-latency"
  alarm_description   = "Lambda ${each.key} P99 latency exceeded 5s"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  extended_statistic  = "p99"
  threshold           = 5000 # 5 seconds in ms
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
}

# Throttle alarm
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = local.lambdas

  alarm_name          = "${each.value}-throttles"
  alarm_description   = "Lambda ${each.key} is being throttled"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
}

# API Gateway 5xx alarm
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project_name}-${var.environment}-api-5xx"
  alarm_description   = "API Gateway 5xx error rate exceeded threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.main.id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Invocations"
          period = 60
          stat   = "Sum"
          metrics = [
            for name, fn in local.lambdas : ["AWS/Lambda", "Invocations", "FunctionName", fn]
          ]
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Errors"
          period = 60
          stat   = "Sum"
          metrics = [
            for name, fn in local.lambdas : ["AWS/Lambda", "Errors", "FunctionName", fn]
          ]
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title  = "Lambda P99 Duration (ms)"
          period = 60
          stat   = "p99"
          metrics = [
            for name, fn in local.lambdas : ["AWS/Lambda", "Duration", "FunctionName", fn]
          ]
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway Requests"
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", aws_apigatewayv2_api.main.id],
            ["AWS/ApiGateway", "5XXError", "ApiId", aws_apigatewayv2_api.main.id],
            ["AWS/ApiGateway", "4XXError", "ApiId", aws_apigatewayv2_api.main.id],
          ]
        }
      },
    ]
  })
}
