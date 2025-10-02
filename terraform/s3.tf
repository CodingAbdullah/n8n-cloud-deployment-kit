# S3 Bucket for n8n file storage
resource "aws_s3_bucket" "n8n_storage" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = "${local.name_prefix}-storage"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-storage"
    }
  )
}

# S3 Bucket for access logs
resource "aws_s3_bucket" "n8n_storage_logs" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = "${local.name_prefix}-storage-logs"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-storage-logs"
    }
  )
}

# Block public access on logs bucket
resource "aws_s3_bucket_public_access_block" "n8n_storage_logs" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = aws_s3_bucket.n8n_storage_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable logging on main bucket
resource "aws_s3_bucket_logging" "n8n_storage" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = aws_s3_bucket.n8n_storage[0].id

  target_bucket = aws_s3_bucket.n8n_storage_logs[0].id
  target_prefix = "access-logs/"
}

# Enable versioning
resource "aws_s3_bucket_versioning" "n8n_storage" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = aws_s3_bucket.n8n_storage[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable KMS encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "n8n_storage" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = aws_s3_bucket.n8n_storage[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3[0].arn
    }
    bucket_key_enabled = true
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "n8n_storage" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = aws_s3_bucket.n8n_storage[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "n8n_storage" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = aws_s3_bucket.n8n_storage[0].id

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }

  rule {
    id     = "delete-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Data source for ALB DNS
data "aws_lb" "main_dns" {
  count = var.enable_s3_storage ? 1 : 0
  arn   = aws_lb.main.arn
}

# CORS configuration for n8n with improved security
resource "aws_s3_bucket_cors_configuration" "n8n_storage" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = aws_s3_bucket.n8n_storage[0].id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = var.domain_name != "" ? ["https://${var.domain_name}"] : concat(
      ["http://${aws_lb.main.dns_name}"],
      var.enable_https ? ["https://${aws_lb.main.dns_name}"] : []
    )
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
