# n8n Cloud Deployment Kit for AWS

A production-ready, enterprise-grade infrastructure-as-code template for deploying n8n on AWS using Terraform with comprehensive security features.

## What This Kit Provides

This starter kit provisions a fully functional, production-ready cloud environment where n8n can run:

### Core Infrastructure
- **ECS Fargate + Docker** → Runs n8n container reliably, scalable, and managed
- **ALB + ACM** → Exposes n8n UI and webhooks securely over HTTPS with TLS 1.3
- **RDS PostgreSQL** → Stores workflows, execution history, and credentials persistently
- **S3** → Optional storage for attachments, temporary files, or workflow outputs
- **Secrets Manager** → Safely stores API keys and credentials with KMS encryption
- **CloudWatch** → Comprehensive logging, monitoring, and alerting
- **IAM & VPC/Security Groups** → Secure access control and networking

### Enterprise Security Features
- **KMS Encryption** → Customer-managed encryption for all data at rest (RDS, S3, Secrets, Logs)
- **WAF Protection** → AWS WAF with rate limiting and managed rule sets
- **VPC Flow Logs** → Network traffic monitoring and analysis
- **Access Logging** → ALB and S3 access logs for security auditing
- **RDS Enhanced Monitoring** → 60-second interval database metrics
- **SNS Notifications** → CloudWatch alarms with email notifications

### Advanced Features (Optional)
- **RDS Proxy** → Connection pooling for high-availability deployments
- **Redis/ElastiCache** → Queue mode for high-scale n8n deployments
- **ECR** → Private container registry with automated image scanning
- **AWS Backup** → Automated daily, weekly, and monthly backups with retention policies

## What This Kit Does NOT Provide

- Pre-built workflows (you create these in n8n's UI)
- Workflow-specific logic or outputs
- A separate front-end application

## Architecture

```
Internet
    │
    ▼
[WAF] → [Route 53] → [ACM Certificate]
    │
    ▼
[Application Load Balancer + Access Logs]
    │
    ▼
[ECS Fargate Service] ←→ [RDS Proxy (optional)]
    │                              │
    ├─→ [n8n Container]           │
    │   (non-root user)            │
    │                              ▼
    ├─→ [RDS PostgreSQL + KMS Encryption]
    │   (Enhanced Monitoring)
    │
    ├─→ [Redis/ElastiCache (optional)]
    │   (Queue Mode)
    │
    ├─→ [S3 Bucket + KMS Encryption]
    │   (Access Logs)
    │
    ├─→ [ECR (optional)]
    │   (Image Scanning)
    │
    └─→ [Secrets Manager + KMS]
         │
         ├─→ [CloudWatch Logs + KMS]
         │   (VPC Flow Logs)
         │
         └─→ [SNS + Email Notifications]
              │
              └─→ [AWS Backup]
```

## Prerequisites

- **AWS Account** with appropriate permissions (Administrator or PowerUser)
- **Terraform** >= 1.0 ([Download](https://www.terraform.io/downloads))
- **AWS CLI** configured ([Installation Guide](https://aws.amazon.com/cli/))
- **Domain name** for HTTPS setup (optional but strongly recommended)
- **Docker** (optional - only if using custom n8n image)

## Quick Start

### 1. Configure AWS Credentials
```bash
aws configure
```

### 2. Clone and Configure
```bash
# Clone the repository
git clone <your-repo-url>
cd n8n-cloud-deployment-kit

# Copy and edit configuration
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

### 3. Edit Configuration
Edit `terraform.tfvars` with your settings:
```hcl
# Minimum required configuration
aws_region   = "us-east-1"
project_name = "n8n"
environment  = "prod"
domain_name  = "n8n.yourdomain.com"  # IMPORTANT: Update this!
alarm_email  = "your-email@example.com"  # For alarm notifications
```

### 4. Deploy Infrastructure
```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy (takes ~10-15 minutes)
terraform apply
```

### 5. Configure DNS
After deployment, point your domain to the ALB:
```bash
# Get ALB DNS name
terraform output alb_dns_name

# Create CNAME record in your DNS provider:
# n8n.yourdomain.com → <alb-dns-name>
```

### 6. Access n8n
```bash
# Get n8n URL
terraform output n8n_url

# Get credentials
terraform output -json | jq
# Or use the helper script (Linux/Mac):
../scripts/get-credentials.sh
```

## Directory Structure

```
.
├── terraform/                    # Terraform infrastructure code
│   ├── main.tf                  # Main configuration & locals
│   ├── variables.tf             # Input variables with validation
│   ├── outputs.tf               # Output values
│   ├── provider.tf              # AWS provider configuration
│   ├── kms.tf                   # KMS key management (NEW)
│   ├── vpc.tf                   # VPC and networking
│   ├── vpc_flow_logs.tf         # VPC Flow Logs (NEW)
│   ├── security_groups.tf       # Security groups
│   ├── rds.tf                   # RDS PostgreSQL database
│   ├── rds_proxy.tf             # RDS Proxy (NEW)
│   ├── ecs.tf                   # ECS cluster and services
│   ├── alb.tf                   # Application Load Balancer
│   ├── waf.tf                   # WAF protection (NEW)
│   ├── s3.tf                    # S3 bucket configuration
│   ├── secrets.tf               # Secrets Manager
│   ├── iam.tf                   # IAM roles and policies
│   ├── cloudwatch.tf            # CloudWatch logging & alarms
│   ├── backup.tf                # AWS Backup (NEW)
│   ├── ecr.tf                   # ECR repository (NEW)
│   └── elasticache.tf           # Redis for queue mode (NEW)
├── docker/                       # Docker configuration
│   ├── Dockerfile               # Custom n8n image
│   ├── .dockerignore            # Docker ignore file
│   └── README.md                # Docker documentation
├── scripts/                      # Utility scripts
│   ├── deploy.sh                # Automated deployment
│   ├── destroy.sh               # Cleanup script
│   ├── get-credentials.sh       # Retrieve n8n credentials
│   └── logs.sh                  # View CloudWatch logs
├── README.md                     # This file
├── DEPLOYMENT_GUIDE.md           # Detailed deployment guide
├── SECURITY_IMPROVEMENTS.md      # Security documentation
└── VARIABLES_ADDED.md            # Variables reference
```

## Configuration

### Required Variables

- `aws_region` - AWS region for deployment (e.g., "us-east-1")
- `project_name` - Project name used for resource naming
- `environment` - Environment name (dev, staging, prod)
- `domain_name` - Domain name for n8n (required for HTTPS)

### Core Infrastructure Variables

- `n8n_version` - n8n version to deploy (default: "latest")
- `ecs_task_cpu` - CPU units: 256, 512, 1024, 2048, 4096 (default: 512)
- `ecs_task_memory` - Memory in MB: 512, 1024, 2048, 4096, 8192 (default: 1024)
- `db_instance_class` - RDS instance class (default: "db.t3.micro")
- `db_allocated_storage` - RDS storage in GB (default: 20)

### Security & Monitoring Variables

- `alarm_email` - Email for CloudWatch alarm notifications
- `data_classification` - Data classification (public, internal, confidential, restricted)
- `cost_center` - Cost center for billing and cost allocation

### Advanced Features (Optional)

- `enable_rds_proxy` - Enable RDS Proxy for connection pooling (default: false)
- `enable_queue_mode` - Enable Redis for n8n queue mode (default: false)
- `enable_ecr` - Use ECR instead of Docker Hub (default: false)
- `redis_node_type` - Redis instance type (default: "cache.t3.micro")
- `redis_num_cache_clusters` - Number of Redis clusters, 2+ for Multi-AZ (default: 2)

See `terraform/variables.tf` for all 43 available variables with validation rules.

## Post-Deployment

After successful deployment:

1. **Configure DNS** - Point your domain to the ALB DNS name
2. **Wait for ACM Certificate Validation** - Add DNS validation records
3. **Access n8n** - Visit your domain (https://n8n.yourdomain.com)
4. **Get Credentials** - Run `scripts/get-credentials.sh` or check Terraform outputs
5. **Complete n8n Setup** - Follow the n8n setup wizard
6. **Subscribe to Alarms** - Confirm SNS email subscription for notifications
7. **Start Creating Workflows!**

## Monitoring and Logs

### CloudWatch Logs
```bash
# View logs (requires AWS CLI)
aws logs tail /ecs/n8n-prod --follow

# Or use the helper script
./scripts/logs.sh
```

### CloudWatch Dashboard
- Navigate to AWS Console → CloudWatch → Dashboards
- Open `n8n-prod-dashboard`
- View ECS, ALB, RDS, and Redis metrics

### Alarms
CloudWatch alarms monitor:
- ECS CPU/Memory utilization (>80%)
- ALB response time (>5s)
- ALB unhealthy targets
- RDS CPU utilization (>80%)
- RDS free storage (<5GB)
- RDS database connections (>80)
- Redis CPU/Memory (>75%/90%)

All alarms send notifications to your configured email.

### Logs Available
- `/ecs/n8n` - n8n application logs
- `/aws/vpc/n8n-prod-flow-logs` - VPC Flow Logs
- `/aws/waf/n8n-prod` - WAF logs
- `/aws/elasticache/n8n-prod` - Redis logs (if enabled)
- S3 buckets for ALB and S3 access logs

## Security Features

### Encryption
- ✅ **All data encrypted at rest** with customer-managed KMS keys
- ✅ **All data encrypted in transit** with TLS 1.3
- ✅ **Automatic key rotation** enabled on all KMS keys

### Network Security
- ✅ **WAF protection** with rate limiting and AWS Managed Rules
- ✅ **VPC Flow Logs** for network traffic analysis
- ✅ **Private subnets** for databases and ECS tasks
- ✅ **Security groups** with least-privilege access
- ✅ **No public database access**

### Access Control
- ✅ **IAM roles** with specific, scoped permissions
- ✅ **Secrets Manager** for credential management
- ✅ **Non-root containers** for ECS tasks
- ✅ **RDS deletion protection** enabled by default

### Compliance & Auditing
- ✅ **Comprehensive logging** (VPC, ALB, S3, WAF, Application)
- ✅ **CloudWatch alarms** for security and performance
- ✅ **AWS Backup** with automated retention policies
- ✅ **Tagged resources** for cost allocation and compliance

See `SECURITY_IMPROVEMENTS.md` for complete security documentation.

## Cost Optimization

### Development/Testing (~$30-50/month)
```hcl
environment              = "dev"
db_instance_class        = "db.t3.micro"
db_multi_az              = false
ecs_task_cpu             = 256
ecs_task_memory          = 512
enable_rds_proxy         = false
enable_queue_mode        = false
log_retention_days       = 7
```

### Production (~$150-300/month)
```hcl
environment              = "prod"
db_instance_class        = "db.t3.small"
db_multi_az              = true
ecs_task_cpu             = 1024
ecs_task_memory          = 2048
ecs_min_count            = 2
enable_rds_proxy         = true
enable_queue_mode        = true  # For high-scale
log_retention_days       = 30
```

### Cost Breakdown
- **VPC & Networking**: ~$30-60/month (NAT Gateways)
- **ECS Fargate**: ~$15-60/month (based on CPU/Memory)
- **RDS**: ~$15-100/month (based on instance class & Multi-AZ)
- **ALB**: ~$20-30/month
- **S3 & Logs**: ~$5-20/month
- **KMS Keys**: ~$10/month (8 keys)
- **WAF**: ~$10-30/month
- **RDS Proxy** (optional): ~$15/month
- **Redis** (optional): ~$15-50/month

## Scaling

### Horizontal Scaling
Auto-scaling is configured based on:
- CPU utilization (>70%)
- Memory utilization (>70%)
- ALB request count (>1000 requests/target)

Configure in `terraform.tfvars`:
```hcl
ecs_min_count = 2   # Minimum tasks
ecs_max_count = 10  # Maximum tasks
```

### Vertical Scaling
Adjust task size:
```hcl
ecs_task_cpu    = 2048  # 2 vCPU
ecs_task_memory = 4096  # 4 GB RAM
```

### Database Scaling
```hcl
db_instance_class        = "db.t3.medium"  # Larger instance
db_max_allocated_storage = 500             # Auto-scaling storage
enable_rds_proxy         = true            # Connection pooling
```

### Queue Mode (High-Scale)
For deployments processing >1000 workflows/hour:
```hcl
enable_queue_mode        = true
redis_node_type          = "cache.t3.medium"
redis_num_cache_clusters = 2  # Multi-AZ
```

## Backup and Disaster Recovery

### Automated Backups
- **RDS Automated Backups**: 7 days retention (configurable)
- **AWS Backup - Daily**: 30 days retention
- **AWS Backup - Weekly**: 90 days retention
- **AWS Backup - Monthly**: 365 days retention (prod only)

### Manual Backup
```bash
# Create RDS snapshot
aws rds create-db-snapshot \
  --db-instance-identifier n8n-prod-db \
  --db-snapshot-identifier n8n-manual-backup-$(date +%Y%m%d)
```

### Disaster Recovery
1. RDS snapshots can be restored to new instances
2. Point-in-time recovery available (within retention period)
3. Cross-region backup replication can be configured
4. Infrastructure can be recreated with `terraform apply`

## Updating n8n

### Minor Version Update
```hcl
# Edit terraform.tfvars
n8n_version = "1.20.0"
```

```bash
terraform apply
# ECS performs rolling update with zero downtime
```

### Major Version Update
1. Test in development environment first
2. Review n8n release notes for breaking changes
3. Backup database before updating
4. Update `n8n_version` in terraform.tfvars
5. Apply changes with `terraform apply`

## Cleanup

### Using the Destroy Script (Recommended)
```bash
./scripts/destroy.sh
```

### Manual Destruction
```bash
# Disable RDS deletion protection first
aws rds modify-db-instance \
  --db-instance-identifier n8n-prod-db \
  --no-deletion-protection \
  --apply-immediately

# Wait a moment, then destroy
terraform destroy
```

⚠️ **Warning**: This will permanently delete:
- All n8n workflows and data
- RDS database (final snapshot created if deletion protection enabled)
- S3 buckets and logs
- All infrastructure

**Always backup important data before destroying!**

## Troubleshooting

### Common Issues

**Issue: Can't access n8n via domain**
- Check DNS propagation: `nslookup n8n.yourdomain.com`
- Verify ACM certificate is validated
- Check ALB target health: AWS Console → EC2 → Target Groups

**Issue: High database connections**
- Enable RDS Proxy: `enable_rds_proxy = true`
- Check for connection leaks in workflows
- Review CloudWatch database metrics

**Issue: Slow performance**
- Increase ECS task size
- Enable RDS Multi-AZ
- Enable queue mode for high-scale
- Review CloudWatch metrics

**Issue: Costs too high**
- Review NAT Gateway usage (biggest cost)
- Reduce log retention periods
- Use smaller instance sizes for non-prod
- Disable unused features

See `DEPLOYMENT_GUIDE.md` for detailed troubleshooting.

## Documentation

- **DEPLOYMENT_GUIDE.md** - Step-by-step deployment instructions
- **SECURITY_IMPROVEMENTS.md** - Security features and compliance
- **VARIABLES_ADDED.md** - Complete variables reference
- **docker/README.md** - Custom Docker image guide

## Support and Contributing

### Getting Help
- Review documentation in this repository
- Check [n8n Documentation](https://docs.n8n.io/)
- Visit [n8n Community](https://community.n8n.io/)
- Open a GitHub issue for deployment kit issues

### Contributing
Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Built for [n8n.io](https://n8n.io/) - Fair-code workflow automation
- Follows AWS Well-Architected Framework
- Implements security best practices from CIS AWS Foundations Benchmark

---

**Production-Ready** | **Enterprise Security** | **Auto-Scaling** | **Fully Monitored** | **Disaster Recovery**
