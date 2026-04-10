variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project identifier — used in resource names"
  type        = string
  default     = "serverless-api"
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "lambda_memory_mb" {
  description = "Memory (MB) allocated to each Lambda function"
  type        = number
  default     = 256

  validation {
    condition     = var.lambda_memory_mb >= 128 && var.lambda_memory_mb <= 10240
    error_message = "Lambda memory must be between 128 and 10240 MB."
  }
}

variable "lambda_timeout_seconds" {
  description = "Lambda execution timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_s3_bucket" {
  description = "S3 bucket that holds the Lambda deployment ZIP"
  type        = string
  # Set via TF_VAR_lambda_s3_bucket or tfvars — never hardcoded
}

variable "lambda_s3_key" {
  description = "S3 object key for the Lambda ZIP file"
  type        = string
  default     = "lambda/package.zip"
}

variable "cloudwatch_alarm_email" {
  description = "Email address for CloudWatch alarm notifications (optional)"
  type        = string
  default     = ""
}

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
}
