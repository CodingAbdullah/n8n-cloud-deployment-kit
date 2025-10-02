# Secrets Manager for n8n credentials
resource "aws_secretsmanager_secret" "n8n_credentials" {
  name        = "${local.name_prefix}-credentials"
  description = "Credentials and sensitive configuration for n8n"
  kms_key_id  = aws_kms_key.secrets.id

  recovery_window_in_days = 7

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "n8n_credentials" {
  secret_id = aws_secretsmanager_secret.n8n_credentials.id

  secret_string = jsonencode({
    db_host                 = aws_db_instance.n8n.address
    db_port                 = aws_db_instance.n8n.port
    db_name                 = aws_db_instance.n8n.db_name
    db_user                 = var.db_username
    db_password             = local.db_password
    n8n_encryption_key      = local.n8n_encryption_key
    n8n_basic_auth_user     = var.n8n_basic_auth_user
    n8n_basic_auth_password = local.n8n_basic_auth_password
  })
}

# Parameter Store for non-sensitive configuration (optional alternative)
resource "aws_ssm_parameter" "n8n_host" {
  name  = "/${var.project_name}/${var.environment}/n8n/host"
  type  = "String"
  value = var.domain_name != "" ? var.domain_name : aws_lb.main.dns_name

  tags = local.common_tags
}

resource "aws_ssm_parameter" "n8n_protocol" {
  name  = "/${var.project_name}/${var.environment}/n8n/protocol"
  type  = "String"
  value = var.enable_https ? "https" : "http"

  tags = local.common_tags
}
