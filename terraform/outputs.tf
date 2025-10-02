output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "n8n_url" {
  description = "URL to access n8n"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.n8n.name
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.n8n.endpoint
  sensitive   = true
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.n8n.db_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for file storage"
  value       = var.enable_s3_storage ? aws_s3_bucket.n8n_storage[0].id : null
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.n8n.name
}

output "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.n8n_credentials.arn
  sensitive   = true
}

output "deployment_instructions" {
  description = "Post-deployment instructions"
  value       = <<-EOT

    ========================================
    n8n Deployment Complete!
    ========================================

    Next Steps:

    1. Access n8n:
       URL: ${var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"}

    ${var.domain_name != "" ? "2. DNS Configuration:\n   - Create a CNAME record in your DNS provider\n   - Point ${var.domain_name} to ${aws_lb.main.dns_name}\n   - Or create an A record (alias) pointing to the ALB\n" : ""}

    3. View Logs:
       - Log Group: ${aws_cloudwatch_log_group.n8n.name}
       - Command: aws logs tail ${aws_cloudwatch_log_group.n8n.name} --follow

    4. Database Connection:
       - Endpoint: ${aws_db_instance.n8n.endpoint}
       - Database: ${aws_db_instance.n8n.db_name}

    5. Retrieve Secrets:
       - Command: aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.n8n_credentials.name}

    ${var.enable_s3_storage ? "6. S3 Bucket:\n   - Name: ${aws_s3_bucket.n8n_storage[0].id}\n   - Region: ${var.aws_region}\n" : ""}

    For more information, visit the project README.
    ========================================
  EOT
}
