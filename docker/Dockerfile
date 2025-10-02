# Custom n8n Dockerfile with additional tools and configurations
# Based on official n8n image with enhancements

FROM n8nio/n8n:latest

# Switch to root for installations
USER root

# Install additional system dependencies (optional)
# Uncomment and add packages as needed for your workflows
# RUN apk add --no-cache \
#     python3 \
#     py3-pip \
#     postgresql-client \
#     mysql-client \
#     git \
#     curl \
#     bash

# Install additional npm packages globally (optional)
# Uncomment and add packages needed for your n8n workflows
# RUN npm install -g \
#     @aws-sdk/client-s3 \
#     axios \
#     lodash

# Create directories for custom nodes and configuration
RUN mkdir -p /home/node/.n8n/custom \
    && mkdir -p /home/node/.n8n/nodes

# Copy custom nodes if you have any (optional)
# COPY custom-nodes/ /home/node/.n8n/custom/

# Set proper permissions
RUN chown -R node:node /home/node/.n8n

# Switch back to node user for security
USER node

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:5678/healthz || exit 1

# Environment variables (these will be overridden by ECS task definition)
ENV N8N_PORT=5678
ENV N8N_METRICS=true
ENV N8N_LOG_LEVEL=info
ENV N8N_LOG_OUTPUT=console

# Expose n8n port
EXPOSE 5678

# Use the default entrypoint and command from the base image
# which is typically: n8n start
