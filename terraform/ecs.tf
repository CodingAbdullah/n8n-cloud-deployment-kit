# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.n8n.name
      }
    }
  }

  tags = local.common_tags
}

# Locals for database endpoint (RDS or RDS Proxy)
locals {
  db_endpoint = var.enable_rds_proxy ? aws_db_proxy.n8n[0].endpoint : aws_db_instance.n8n.address
  db_port     = 5432

  # Redis connection string (if queue mode is enabled)
  redis_host = var.enable_queue_mode ? aws_elasticache_replication_group.n8n[0].primary_endpoint_address : ""

  # Determine image source
  n8n_image = var.enable_ecr ? "${aws_ecr_repository.n8n[0].repository_url}:${var.n8n_version}" : "n8nio/n8n:${var.n8n_version}"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "n8n" {
  family                   = "${local.name_prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "n8n"
      image = local.n8n_image
      user  = "node" # Run as non-root user

      portMappings = [
        {
          containerPort = 5678
          protocol      = "tcp"
        }
      ]

      environment = concat([
        {
          name  = "N8N_HOST"
          value = var.domain_name != "" ? var.domain_name : aws_lb.main.dns_name
        },
        {
          name  = "N8N_PORT"
          value = "5678"
        },
        {
          name  = "N8N_PROTOCOL"
          value = var.enable_https ? "https" : "http"
        },
        {
          name  = "WEBHOOK_URL"
          value = var.domain_name != "" ? "${var.enable_https ? "https" : "http"}://${var.domain_name}/" : "http://${aws_lb.main.dns_name}/"
        },
        {
          name  = "DB_TYPE"
          value = "postgresdb"
        },
        {
          name  = "EXECUTIONS_MODE"
          value = var.enable_queue_mode ? "queue" : "regular"
        },
        {
          name  = "N8N_BASIC_AUTH_ACTIVE"
          value = tostring(var.n8n_basic_auth_active)
        },
        {
          name  = "N8N_METRICS"
          value = "true"
        },
        {
          name  = "N8N_LOG_LEVEL"
          value = var.environment == "prod" ? "info" : "debug"
        },
        {
          name  = "N8N_LOG_OUTPUT"
          value = "console"
        },
        {
          name  = "GENERIC_TIMEZONE"
          value = "UTC"
        },
        {
          name  = "N8N_DIAGNOSTICS_ENABLED"
          value = "false"
        },
        {
          name  = "N8N_VERSION_NOTIFICATIONS_ENABLED"
          value = "false"
        },
        {
          name  = "EXECUTIONS_DATA_PRUNE"
          value = "true"
        },
        {
          name  = "EXECUTIONS_DATA_MAX_AGE"
          value = "168" # 7 days
        },
        {
          name  = "N8N_HIRING_BANNER_ENABLED"
          value = "false"
        },
        {
          name  = "N8N_PERSONALIZATION_ENABLED"
          value = "false"
        },
        {
          name  = "WORKFLOWS_DEFAULT_NAME"
          value = "My Workflow"
        },
        {
          name  = "N8N_PUSH_BACKEND"
          value = "websocket"
        },
        {
          name  = "N8N_SECURE_COOKIE"
          value = var.enable_https ? "true" : "false"
        }
        ],
        # Add Redis configuration if queue mode is enabled
        var.enable_queue_mode ? [
          {
            name  = "QUEUE_BULL_REDIS_HOST"
            value = local.redis_host
          },
          {
            name  = "QUEUE_BULL_REDIS_PORT"
            value = "6379"
          },
          {
            name  = "QUEUE_BULL_REDIS_DB"
            value = "0"
          },
          {
            name  = "QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD"
            value = "10000"
          }
        ] : []
      )

      secrets = concat([
        {
          name      = "DB_POSTGRESDB_HOST"
          valueFrom = "${aws_secretsmanager_secret.n8n_credentials.arn}:db_host::"
        },
        {
          name      = "DB_POSTGRESDB_PORT"
          valueFrom = "${aws_secretsmanager_secret.n8n_credentials.arn}:db_port::"
        },
        {
          name      = "DB_POSTGRESDB_DATABASE"
          valueFrom = "${aws_secretsmanager_secret.n8n_credentials.arn}:db_name::"
        },
        {
          name      = "DB_POSTGRESDB_USER"
          valueFrom = "${aws_secretsmanager_secret.n8n_credentials.arn}:db_user::"
        },
        {
          name      = "DB_POSTGRESDB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.n8n_credentials.arn}:db_password::"
        },
        {
          name      = "N8N_ENCRYPTION_KEY"
          valueFrom = "${aws_secretsmanager_secret.n8n_credentials.arn}:n8n_encryption_key::"
        },
        {
          name      = "N8N_BASIC_AUTH_USER"
          valueFrom = "${aws_secretsmanager_secret.n8n_credentials.arn}:n8n_basic_auth_user::"
        },
        {
          name      = "N8N_BASIC_AUTH_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.n8n_credentials.arn}:n8n_basic_auth_password::"
        }
        ],
        # Add Redis auth token if queue mode is enabled
        var.enable_queue_mode ? [
          {
            name      = "QUEUE_BULL_REDIS_PASSWORD"
            valueFrom = "${aws_secretsmanager_secret.redis_auth[0].arn}:redis_auth_token::"
          }
        ] : []
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.n8n.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "n8n"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:5678/healthz || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      essential = true
    }
  ])

  tags = local.common_tags
}

# Redis auth token secret (if queue mode is enabled)
resource "aws_secretsmanager_secret" "redis_auth" {
  count       = var.enable_queue_mode ? 1 : 0
  name        = "${local.name_prefix}-redis-auth"
  description = "Redis authentication token for n8n queue mode"
  kms_key_id  = aws_kms_key.secrets.id

  recovery_window_in_days = 7

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  count     = var.enable_queue_mode ? 1 : 0
  secret_id = aws_secretsmanager_secret.redis_auth[0].id

  secret_string = jsonencode({
    redis_auth_token = local.redis_auth_token
  })
}

# ECS Service
resource "aws_ecs_service" "n8n" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.n8n.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  platform_version = "LATEST"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.n8n.arn
    container_name   = "n8n"
    container_port   = 5678
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  enable_execute_command = true

  tags = local.common_tags

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy.ecs_secrets_policy
  ]

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.ecs_max_count
  min_capacity       = var.ecs_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.n8n.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  role_arn           = aws_iam_role.ecs_autoscaling.arn
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "${local.name_prefix}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "ecs_memory" {
  name               = "${local.name_prefix}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - ALB Request Count
resource "aws_appautoscaling_policy" "ecs_requests" {
  name               = "${local.name_prefix}-request-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.n8n.arn_suffix}"
    }

    target_value       = 1000.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
