##############################################################################
# Shared assume-role policy for all Lambda functions
##############################################################################
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    sid     = "AllowLambdaAssumeRole"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

##############################################################################
# create_item — write-only access
##############################################################################
resource "aws_iam_role" "create_item" {
  name               = "${var.project_name}-${var.environment}-create-item"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "create_item_dynamodb" {
  name = "dynamodb-write"
  role = aws_iam_role.create_item.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:PutItem"]
      Resource = [aws_dynamodb_table.items.arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "create_item_logs" {
  role       = aws_iam_role.create_item.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

##############################################################################
# get_item — read-only access
##############################################################################
resource "aws_iam_role" "get_item" {
  name               = "${var.project_name}-${var.environment}-get-item"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "get_item_dynamodb" {
  name = "dynamodb-read"
  role = aws_iam_role.get_item.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem"]
      Resource = [aws_dynamodb_table.items.arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "get_item_logs" {
  role       = aws_iam_role.get_item.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

##############################################################################
# list_items — scan + GSI query access
##############################################################################
resource "aws_iam_role" "list_items" {
  name               = "${var.project_name}-${var.environment}-list-items"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "list_items_dynamodb" {
  name = "dynamodb-scan-query"
  role = aws_iam_role.list_items.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["dynamodb:Scan", "dynamodb:Query"]
      Resource = [
        aws_dynamodb_table.items.arn,
        "${aws_dynamodb_table.items.arn}/index/category-index",
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "list_items_logs" {
  role       = aws_iam_role.list_items.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

##############################################################################
# delete_item — delete-only access
##############################################################################
resource "aws_iam_role" "delete_item" {
  name               = "${var.project_name}-${var.environment}-delete-item"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "delete_item_dynamodb" {
  name = "dynamodb-delete"
  role = aws_iam_role.delete_item.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:DeleteItem"]
      Resource = [aws_dynamodb_table.items.arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "delete_item_logs" {
  role       = aws_iam_role.delete_item.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

##############################################################################
# GitHub Actions OIDC — keyless authentication (no static access keys)
##############################################################################
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-${var.environment}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Replace YOUR_ORG/YOUR_REPO with your actual GitHub org/repo
          "token.actions.githubusercontent.com:sub" = "repo:YOUR_ORG/YOUR_REPO:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "deploy-permissions"
  role = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3DeployBucket"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.lambda_s3_bucket}",
          "arn:aws:s3:::${var.lambda_s3_bucket}/*",
        ]
      },
      {
        Sid    = "LambdaUpdate"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction",
          "lambda:PublishVersion",
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:*:function:${var.project_name}-${var.environment}-*"
      },
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:ListBucket",
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem",
        ]
        Resource = [
          "arn:aws:s3:::YOUR_STATE_BUCKET",
          "arn:aws:s3:::YOUR_STATE_BUCKET/*",
          "arn:aws:dynamodb:${var.aws_region}:*:table/terraform-state-lock",
        ]
      },
    ]
  })
}
