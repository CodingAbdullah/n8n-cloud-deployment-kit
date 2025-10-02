#!/bin/bash

# n8n AWS Cleanup Script
# This script helps destroy n8n infrastructure from AWS using Terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install Terraform first."
    exit 1
fi

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform" || exit 1

# Warning message
print_error "========================================="
print_error "WARNING: This will DESTROY all resources!"
print_error "========================================="
print_warning "This includes:"
print_warning "  - ECS Cluster and Services"
print_warning "  - Application Load Balancer"
print_warning "  - RDS Database (and all data)"
print_warning "  - S3 Bucket (if enabled)"
print_warning "  - VPC and all networking"
print_warning "  - CloudWatch Logs"
print_warning "  - Secrets Manager entries"
print_error "========================================="

# First confirmation
read -p "Are you absolutely sure you want to destroy everything? (type 'destroy'): " confirm1

if [ "$confirm1" != "destroy" ]; then
    print_info "Destruction cancelled."
    exit 0
fi

# Second confirmation
read -p "This is your last chance. Type 'yes' to confirm destruction: " confirm2

if [ "$confirm2" != "yes" ]; then
    print_info "Destruction cancelled."
    exit 0
fi

# Create a backup reminder
print_warning "Have you backed up your database and any important data? (yes/no)"
read -p "Answer: " backup_confirm

if [ "$backup_confirm" != "yes" ]; then
    print_info "Please backup your data first, then run this script again."
    exit 0
fi

# Disable deletion protection on RDS (if needed)
print_info "Checking RDS deletion protection..."
RDS_IDENTIFIER=$(terraform output -raw rds_endpoint 2>/dev/null | cut -d':' -f1 || echo "")

if [ -n "$RDS_IDENTIFIER" ]; then
    print_warning "Disabling RDS deletion protection..."
    aws rds modify-db-instance \
        --db-instance-identifier "$RDS_IDENTIFIER" \
        --no-deletion-protection \
        --apply-immediately || print_warning "Could not disable deletion protection automatically"

    print_info "Waiting for modification to apply..."
    sleep 10
fi

# Destroy infrastructure
print_info "Destroying infrastructure..."
terraform destroy -auto-approve

print_info "========================================="
print_info "Infrastructure destroyed successfully!"
print_info "========================================="
print_warning "Note: Some resources may have a deletion protection period:"
print_warning "  - RDS snapshots (if enabled)"
print_warning "  - Secrets Manager secrets (7-day recovery window)"
print_warning "  - CloudWatch log groups (if retention is set)"
print_info "========================================="
