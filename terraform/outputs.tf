output "api_endpoint" {
  description = "Base URL of the HTTP API"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.main.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.items.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.items.arn
}

output "lambda_functions" {
  description = "Map of Lambda function names"
  value = {
    create_item = aws_lambda_function.create_item.function_name
    get_item    = aws_lambda_function.get_item.function_name
    list_items  = aws_lambda_function.list_items.function_name
    delete_item = aws_lambda_function.delete_item.function_name
  }
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC — set as GH secret AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}
