#!/bin/bash

# n8n Logs Viewer Script
# This script tails CloudWatch logs for n8n

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

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform" || exit 1

# Get the log group name from Terraform outputs
print_info "Retrieving log group information from Terraform..."
LOG_GROUP=$(terraform output -raw cloudwatch_log_group 2>/dev/null)

if [ -z "$LOG_GROUP" ]; then
    print_error "Could not retrieve log group from Terraform outputs."
    print_error "Make sure you have deployed the infrastructure first."
    exit 1
fi

print_info "Log Group: $LOG_GROUP"
print_info "Tailing logs (Press Ctrl+C to stop)..."
print_info "========================================="

# Tail the logs
aws logs tail "$LOG_GROUP" --follow --format short
