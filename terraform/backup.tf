# AWS Backup Vault
resource "aws_backup_vault" "main" {
  name        = "${local.name_prefix}-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn

  tags = local.common_tags
}

# Backup Plan
resource "aws_backup_plan" "main" {
  name = "${local.name_prefix}-backup-plan"

  # Daily backups
  rule {
    rule_name         = "daily_backups"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 2 * * ? *)"

    lifecycle {
      delete_after = 30
    }

    recovery_point_tags = merge(
      local.common_tags,
      {
        BackupType = "Daily"
      }
    )
  }

  # Weekly backups
  rule {
    rule_name         = "weekly_backups"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 ? * 1 *)"

    lifecycle {
      delete_after = 90
    }

    recovery_point_tags = merge(
      local.common_tags,
      {
        BackupType = "Weekly"
      }
    )
  }

  # Monthly backups (for production)
  rule {
    rule_name         = "monthly_backups"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 4 1 * ? *)"

    lifecycle {
      delete_after = var.environment == "prod" ? 365 : 180
    }

    recovery_point_tags = merge(
      local.common_tags,
      {
        BackupType = "Monthly"
      }
    )
  }

  tags = local.common_tags
}

# Backup Selection for RDS
resource "aws_backup_selection" "rds" {
  name         = "${local.name_prefix}-rds-backup-selection"
  plan_id      = aws_backup_plan.main.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = [
    aws_db_instance.n8n.arn
  ]
}

# Backup notifications (optional)
resource "aws_backup_vault_notifications" "main" {
  backup_vault_name   = aws_backup_vault.main.name
  sns_topic_arn       = aws_sns_topic.alarms.arn
  backup_vault_events = ["BACKUP_JOB_COMPLETED", "RESTORE_JOB_COMPLETED", "BACKUP_JOB_FAILED", "RESTORE_JOB_FAILED"]
}
