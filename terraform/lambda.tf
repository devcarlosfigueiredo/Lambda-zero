##############################################################################
# Common Lambda configuration locals
##############################################################################
locals {
  runtime     = "python3.12"
  source_dir  = "${path.root}/../src"

  common_env = {
    DYNAMODB_TABLE = aws_dynamodb_table.items.name
    AWS_REGION     = var.aws_region
    ENVIRONMENT    = var.environment
    LOG_LEVEL      = var.environment == "prod" ? "WARNING" : "INFO"
  }
}

##############################################################################
# create_item Lambda
##############################################################################
resource "aws_lambda_function" "create_item" {
  function_name = "${var.project_name}-${var.environment}-create-item"
  description   = "POST /items — creates a new item in DynamoDB"
  role          = aws_iam_role.create_item.arn

  s3_bucket = var.lambda_s3_bucket
  s3_key    = var.lambda_s3_key

  runtime     = local.runtime
  handler     = "handlers.create_item.handler"
  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  environment {
    variables = local.common_env
  }

  tracing_config {
    mode = "Active" # AWS X-Ray tracing
  }

  depends_on = [aws_iam_role_policy_attachment.create_item_logs]
}

resource "aws_cloudwatch_log_group" "create_item" {
  name              = "/aws/lambda/${aws_lambda_function.create_item.function_name}"
  retention_in_days = 14
}

##############################################################################
# get_item Lambda
##############################################################################
resource "aws_lambda_function" "get_item" {
  function_name = "${var.project_name}-${var.environment}-get-item"
  description   = "GET /items/{id} — fetches a single item from DynamoDB"
  role          = aws_iam_role.get_item.arn

  s3_bucket = var.lambda_s3_bucket
  s3_key    = var.lambda_s3_key

  runtime     = local.runtime
  handler     = "handlers.get_item.handler"
  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  environment {
    variables = local.common_env
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_iam_role_policy_attachment.get_item_logs]
}

resource "aws_cloudwatch_log_group" "get_item" {
  name              = "/aws/lambda/${aws_lambda_function.get_item.function_name}"
  retention_in_days = 14
}

##############################################################################
# list_items Lambda
##############################################################################
resource "aws_lambda_function" "list_items" {
  function_name = "${var.project_name}-${var.environment}-list-items"
  description   = "GET /items — lists all items, supports ?category= filter"
  role          = aws_iam_role.list_items.arn

  s3_bucket = var.lambda_s3_bucket
  s3_key    = var.lambda_s3_key

  runtime     = local.runtime
  handler     = "handlers.list_items.handler"
  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  environment {
    variables = local.common_env
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_iam_role_policy_attachment.list_items_logs]
}

resource "aws_cloudwatch_log_group" "list_items" {
  name              = "/aws/lambda/${aws_lambda_function.list_items.function_name}"
  retention_in_days = 14
}

##############################################################################
# delete_item Lambda
##############################################################################
resource "aws_lambda_function" "delete_item" {
  function_name = "${var.project_name}-${var.environment}-delete-item"
  description   = "DELETE /items/{id} — removes an item from DynamoDB"
  role          = aws_iam_role.delete_item.arn

  s3_bucket = var.lambda_s3_bucket
  s3_key    = var.lambda_s3_key

  runtime     = local.runtime
  handler     = "handlers.delete_item.handler"
  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  environment {
    variables = local.common_env
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_iam_role_policy_attachment.delete_item_logs]
}

resource "aws_cloudwatch_log_group" "delete_item" {
  name              = "/aws/lambda/${aws_lambda_function.delete_item.function_name}"
  retention_in_days = 14
}
