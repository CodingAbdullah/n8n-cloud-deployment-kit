#!/bin/bash

# n8n Credentials Retrieval Script
# This script retrieves n8n credentials from AWS Secrets Manager

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install AWS CLI first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_warning "jq is not installed. Output will be in JSON format."
    JQ_INSTALLED=false
else
    JQ_INSTALLED=true
fi

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform" || exit 1

# Get the secret ARN from Terraform outputs
print_info "Retrieving secret information from Terraform..."
SECRET_ARN=$(terraform output -raw secrets_manager_arn 2>/dev/null)

if [ -z "$SECRET_ARN" ]; then
    print_error "Could not retrieve secret ARN from Terraform outputs."
    print_error "Make sure you have deployed the infrastructure first."
    exit 1
fi

print_info "Retrieving credentials from AWS Secrets Manager..."

# Get the secret value
SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text)

if [ -z "$SECRET_VALUE" ]; then
    print_error "Could not retrieve secret value."
    exit 1
fi

print_info "========================================="
print_info "n8n Credentials"
print_info "========================================="

if [ "$JQ_INSTALLED" = true ]; then
    echo "$SECRET_VALUE" | jq -r '
        "Database Host: " + .db_host,
        "Database Port: " + (.db_port | tostring),
        "Database Name: " + .db_name,
        "Database User: " + .db_user,
        "Database Password: " + .db_password,
        "",
        "n8n Basic Auth User: " + .n8n_basic_auth_user,
        "n8n Basic Auth Password: " + .n8n_basic_auth_password,
        "",
        "n8n Encryption Key: " + .n8n_encryption_key
    '
else
    echo "$SECRET_VALUE"
fi

print_info "========================================="
print_warning "Keep these credentials secure!"
print_info "========================================="
