# S3 Bucket for CI/CD Artifacts and Application Data
resource "aws_s3_bucket" "cicd_bucket" {
  bucket = "${var.project_name}-${var.environment}-cicd-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-cicd-bucket"
    Environment = var.environment
    Purpose     = "CI/CD Artifacts and Application Data"
  }
}

# Enable versioning for rollback capability
resource "aws_s3_bucket_versioning" "cicd_bucket_versioning" {
  bucket = aws_s3_bucket.cicd_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "cicd_bucket_pab" {
  bucket = aws_s3_bucket.cicd_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "cicd_bucket_encryption" {
  bucket = aws_s3_bucket.cicd_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable logging for audit trail
resource "aws_s3_bucket_logging" "cicd_bucket_logging" {
  bucket = aws_s3_bucket.cicd_bucket.id

  target_bucket = aws_s3_bucket.cicd_logs_bucket.id
  target_prefix = "cicd-bucket-logs/"
}

# Logging bucket for S3 access logs
resource "aws_s3_bucket" "cicd_logs_bucket" {
  bucket = "${var.project_name}-${var.environment}-cicd-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-cicd-logs-bucket"
    Environment = var.environment
    Purpose     = "S3 Access Logs"
  }
}

# Block public access on logging bucket
resource "aws_s3_bucket_public_access_block" "cicd_logs_pab" {
  bucket = aws_s3_bucket.cicd_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for logs bucket (delete old logs after 90 days)
resource "aws_s3_bucket_lifecycle_configuration" "cicd_logs_lifecycle" {
  bucket = aws_s3_bucket.cicd_logs_bucket.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

# Lifecycle policy for main bucket (transition old versions to Glacier)
resource "aws_s3_bucket_lifecycle_configuration" "cicd_bucket_lifecycle" {
  bucket = aws_s3_bucket.cicd_bucket.id

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Bucket policy for GitHub Actions access
resource "aws_s3_bucket_policy" "cicd_bucket_policy" {
  bucket = aws_s3_bucket.cicd_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGitHubActionsECRAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.github_actions_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion"
        ]
        Resource = [
          aws_s3_bucket.cicd_bucket.arn,
          "${aws_s3_bucket.cicd_bucket.arn}/*"
        ]
      },
      {
        Sid    = "AllowEC2InstancesAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.ec2_instance_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.cicd_bucket.arn,
          "${aws_s3_bucket.cicd_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Get AWS account ID for bucket naming
data "aws_caller_identity" "current" {}
