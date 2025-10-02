# Generate random strings for passwords if not provided
resource "random_password" "db_password" {
  count            = var.db_password == "" ? 1 : 0
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_special      = 2
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
}

resource "random_password" "n8n_encryption_key" {
  count   = var.n8n_encryption_key == "" ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "n8n_basic_auth_password" {
  count            = var.n8n_basic_auth_password == "" ? 1 : 0
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_special      = 1
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
}

resource "random_password" "redis_auth" {
  count   = var.enable_queue_mode ? 1 : 0
  length  = 32
  special = false
}

# Local values
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  db_password             = var.db_password != "" ? var.db_password : random_password.db_password[0].result
  n8n_encryption_key      = var.n8n_encryption_key != "" ? var.n8n_encryption_key : random_password.n8n_encryption_key[0].result
  n8n_basic_auth_password = var.n8n_basic_auth_password != "" ? var.n8n_basic_auth_password : random_password.n8n_basic_auth_password[0].result
  redis_auth_token        = var.enable_queue_mode ? random_password.redis_auth[0].result : ""

  common_tags = merge(
    {
      Project            = var.project_name
      Environment        = var.environment
      ManagedBy          = "Terraform"
      DataClassification = var.data_classification
      BackupPolicy       = "Daily"
      CostCenter         = var.cost_center != "" ? var.cost_center : var.project_name
    },
    var.additional_tags
  )
}
