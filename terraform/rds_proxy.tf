# RDS Proxy for connection pooling
resource "aws_db_proxy" "n8n" {
  count = var.enable_rds_proxy ? 1 : 0

  name                = "${local.name_prefix}-rds-proxy"
  debug_logging       = false
  engine_family       = "POSTGRESQL"
  idle_client_timeout = 1800
  require_tls         = true
  role_arn            = aws_iam_role.rds_proxy[0].arn
  vpc_subnet_ids      = aws_subnet.private[*].id

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.n8n_credentials.arn
  }

  tags = local.common_tags
}

# RDS Proxy Target Group
resource "aws_db_proxy_default_target_group" "n8n" {
  count         = var.enable_rds_proxy ? 1 : 0
  db_proxy_name = aws_db_proxy.n8n[0].name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
    session_pinning_filters      = ["EXCLUDE_VARIABLE_SETS"]
  }
}

# RDS Proxy Target
resource "aws_db_proxy_target" "n8n" {
  count                  = var.enable_rds_proxy ? 1 : 0
  db_instance_identifier = aws_db_instance.n8n.id
  db_proxy_name          = aws_db_proxy.n8n[0].name
  target_group_name      = aws_db_proxy_default_target_group.n8n[0].name
}

# Security Group for RDS Proxy
resource "aws_security_group" "rds_proxy" {
  count       = var.enable_rds_proxy ? 1 : 0
  name_prefix = "${local.name_prefix}-rds-proxy-"
  description = "Security group for RDS Proxy"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-rds-proxy-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Update RDS Proxy with security group
resource "aws_db_proxy_endpoint" "n8n" {
  count                  = var.enable_rds_proxy ? 1 : 0
  db_proxy_name          = aws_db_proxy.n8n[0].name
  db_proxy_endpoint_name = "${local.name_prefix}-read-write"
  vpc_subnet_ids         = aws_subnet.private[*].id
  target_role            = "READ_WRITE"
  vpc_security_group_ids = [aws_security_group.rds_proxy[0].id]

  tags = local.common_tags
}
