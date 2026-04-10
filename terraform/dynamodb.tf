resource "aws_dynamodb_table" "items" {
  name         = "${var.project_name}-${var.environment}-items"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  # Global Secondary Index for category-based queries
  global_secondary_index {
    name            = "category-index"
    hash_key        = "category"
    projection_type = "ALL"
  }

  # Point-in-time recovery — free, enables restore to any second in last 35 days
  point_in_time_recovery {
    enabled = true
  }

  # Encryption at rest (AWS-managed key — no extra cost)
  server_side_encryption {
    enabled = true
  }

  # Prevent accidental deletion in production
  deletion_protection_enabled = var.environment == "prod"

  tags = {
    Name = "${var.project_name}-${var.environment}-items"
  }
}
