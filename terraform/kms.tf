# Data source for current AWS account
data "aws_caller_identity" "current" {}

# KMS Key for RDS Encryption
resource "aws_kms_key" "rds" {
  description             = "${local.name_prefix}-rds-encryption-key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-rds-kms"
    }
  )
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# KMS Key for Secrets Manager
resource "aws_kms_key" "secrets" {
  description             = "${local.name_prefix}-secrets-encryption-key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-secrets-kms"
    }
  )
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${local.name_prefix}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# KMS Key for CloudWatch Logs
resource "aws_kms_key" "logs" {
  description             = "${local.name_prefix}-logs-encryption-key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-logs-kms"
    }
  )
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${local.name_prefix}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

# KMS Key for S3
resource "aws_kms_key" "s3" {
  count                   = var.enable_s3_storage ? 1 : 0
  description             = "${local.name_prefix}-s3-encryption-key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-s3-kms"
    }
  )
}

resource "aws_kms_alias" "s3" {
  count         = var.enable_s3_storage ? 1 : 0
  name          = "alias/${local.name_prefix}-s3"
  target_key_id = aws_kms_key.s3[0].key_id
}

# KMS Key for SNS
resource "aws_kms_key" "sns" {
  description             = "${local.name_prefix}-sns-encryption-key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch to use the key"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow SNS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-sns-kms"
    }
  )
}

resource "aws_kms_alias" "sns" {
  name          = "alias/${local.name_prefix}-sns"
  target_key_id = aws_kms_key.sns.key_id
}

# KMS Key for ECR
resource "aws_kms_key" "ecr" {
  count                   = var.enable_ecr ? 1 : 0
  description             = "${local.name_prefix}-ecr-encryption-key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ecr-kms"
    }
  )
}

resource "aws_kms_alias" "ecr" {
  count         = var.enable_ecr ? 1 : 0
  name          = "alias/${local.name_prefix}-ecr"
  target_key_id = aws_kms_key.ecr[0].key_id
}

# KMS Key for Backup Vault
resource "aws_kms_key" "backup" {
  description             = "${local.name_prefix}-backup-encryption-key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-backup-kms"
    }
  )
}

resource "aws_kms_alias" "backup" {
  name          = "alias/${local.name_prefix}-backup"
  target_key_id = aws_kms_key.backup.key_id
}

# KMS Key for ElastiCache (Redis)
resource "aws_kms_key" "redis" {
  count                   = var.enable_queue_mode ? 1 : 0
  description             = "${local.name_prefix}-redis-encryption-key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-redis-kms"
    }
  )
}

resource "aws_kms_alias" "redis" {
  count         = var.enable_queue_mode ? 1 : 0
  name          = "alias/${local.name_prefix}-redis"
  target_key_id = aws_kms_key.redis[0].key_id
}
