#!/bin/bash

# n8n AWS Deployment Script
# This script helps deploy n8n infrastructure to AWS using Terraform

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

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install AWS CLI first."
    exit 1
fi

# Check AWS credentials
print_info "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured. Please run 'aws configure'"
    exit 1
fi

print_info "AWS credentials verified"
aws sts get-caller-identity

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform" || exit 1

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_warning "terraform.tfvars not found!"
    print_info "Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    print_warning "Please edit terraform.tfvars with your configuration before proceeding."
    print_warning "Especially update the 'domain_name' variable!"
    exit 1
fi

# Ask for confirmation
print_warning "This will create AWS resources that may incur costs."
read -p "Do you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    print_info "Deployment cancelled."
    exit 0
fi

# Initialize Terraform
print_info "Initializing Terraform..."
terraform init

# Format check
print_info "Checking Terraform formatting..."
terraform fmt -check || terraform fmt

# Validate configuration
print_info "Validating Terraform configuration..."
terraform validate

# Plan deployment
print_info "Creating Terraform plan..."
terraform plan -out=tfplan

# Ask for final confirmation
read -p "Do you want to apply this plan? (yes/no): " apply_confirm

if [ "$apply_confirm" != "yes" ]; then
    print_info "Deployment cancelled."
    rm tfplan
    exit 0
fi

# Apply Terraform
print_info "Applying Terraform configuration..."
terraform apply tfplan

# Clean up plan file
rm tfplan

# Get outputs
print_info "Deployment complete! Here are your outputs:"
terraform output

print_info "========================================="
print_info "Next Steps:"
print_info "1. Point your domain to the ALB DNS name"
print_info "2. Wait for DNS propagation"
print_info "3. Access n8n at your domain"
print_info "4. Retrieve credentials from AWS Secrets Manager"
print_info "========================================="
