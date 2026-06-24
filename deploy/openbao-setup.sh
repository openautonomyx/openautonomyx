#!/bin/bash

# OPENBAO SECRETS SETUP
# Store all deployment credentials in OpenBao

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔐 OPENBAO SECRETS MANAGEMENT SETUP"
echo "==========================================${NC}"
echo ""

# Configuration
BOAS_ADDR="${BOAS_ADDR:-http://localhost:8200}"
BOAS_TOKEN="${BOAS_TOKEN}"
BOAS_NAMESPACE="${BOAS_NAMESPACE:-secret}"

echo -e "${YELLOW}OpenBao Configuration:${NC}"
echo "  Address: $BOAS_ADDR"
echo "  Namespace: $BOAS_NAMESPACE"
echo ""

if [ -z "$BOAS_TOKEN" ]; then
    echo -e "${YELLOW}Step 1: Initialize OpenBao${NC}"
    echo ""
    echo "Run these commands to start OpenBao:"
    echo ""
    echo "  # Docker setup"
    echo "  docker run -d \\"
    echo "    --name openbao \\"
    echo "    --network creative-network \\"
    echo "    -e 'BOAS_DEV_ROOT_TOKEN_ID=root' \\"
    echo "    -p 8200:8200 \\"
    echo "    ghcr.io/openbao/openbao:latest server -dev"
    echo ""
    echo "  # Get the root token"
    echo "  docker logs openbao | grep 'Root Token:'"
    echo ""
    echo "  # Export token"
    echo "  export BOAS_TOKEN='your-root-token'"
    echo ""
    exit 1
fi

# Login to OpenBao
export BOAS_ADDR
export BOAS_TOKEN

echo -e "${YELLOW}Step 2: Creating credential storage structure${NC}"
echo ""

# Enable KV v2 secrets engine
echo "Enabling KV secrets engine at /secret..."
boas secrets enable -version=2 -path=secret kv 2>/dev/null || echo "  (already enabled)"
echo -e "${GREEN}✅ KV secrets enabled${NC}"
echo ""

# Create credentials
echo -e "${YELLOW}Step 3: Storing credentials in OpenBao${NC}"
echo ""

# Generate strong credentials
VPS_PASSWORD=$(openssl rand -base64 32)
DB_PASSWORD=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 32)
LIFERAY_API_KEY=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)
GITHUB_TOKEN=$(read -sp "GitHub token (for Docker): " && echo $REPLY)
STRIPE_API_KEY=$(read -sp "Stripe API key: " && echo $REPLY)
SLACK_WEBHOOK=$(read -sp "Slack webhook URL: " && echo $REPLY)
TEMPORAL_API_KEY=$(read -sp "Temporal Cloud API key: " && echo $REPLY)
CLICKHOUSE_PASSWORD=$(openssl rand -base64 32)

echo ""
echo -e "${YELLOW}Storing credentials...${NC}"
echo ""

# VPS Credentials
echo "Storing VPS credentials..."
boas kv put secret/vps/credentials \
  host="agennext.com" \
  user="almalinux" \
  password="$VPS_PASSWORD" \
  ssh_key=@~/.ssh/id_rsa \
  port="22"
echo -e "${GREEN}✅ VPS credentials stored${NC}"

# Database Credentials
echo "Storing database credentials..."
boas kv put secret/database/postgres \
  host="localhost" \
  port="5432" \
  user="postgres" \
  password="$DB_PASSWORD" \
  database="creative_platform" \
  connection_string="postgres://postgres:$DB_PASSWORD@localhost:5432/creative_platform"
echo -e "${GREEN}✅ Database credentials stored${NC}"

# JWT & Auth Secrets
echo "Storing authentication secrets..."
boas kv put secret/auth/jwt \
  secret="$JWT_SECRET" \
  algorithm="HS256" \
  expiry="24h"
echo -e "${GREEN}✅ JWT secrets stored${NC}"

# Liferay Credentials
echo "Storing Liferay credentials..."
boas kv put secret/liferay/api \
  url="http://localhost:8080" \
  api_key="$LIFERAY_API_KEY" \
  admin_email="admin@liferay.com" \
  admin_password="admin123" \
  api_version="v1"
echo -e "${GREEN}✅ Liferay credentials stored${NC}"

# Redis Credentials
echo "Storing Redis credentials..."
boas kv put secret/redis/cache \
  host="localhost" \
  port="6379" \
  password="$REDIS_PASSWORD" \
  db="0" \
  connection_string="redis://:$REDIS_PASSWORD@localhost:6379/0"
echo -e "${GREEN}✅ Redis credentials stored${NC}"

# GitHub Credentials
echo "Storing GitHub credentials..."
boas kv put secret/github/credentials \
  token="$GITHUB_TOKEN" \
  username="fractional-pm" \
  repository="creative-platform" \
  ghcr_token="$GITHUB_TOKEN" \
  docker_registry="ghcr.io"
echo -e "${GREEN}✅ GitHub credentials stored${NC}"

# Payment Credentials
echo "Storing payment credentials..."
boas kv put secret/payment/stripe \
  api_key="$STRIPE_API_KEY" \
  publishable_key="pk_live_..." \
  webhook_secret="whsec_..."
echo -e "${GREEN}✅ Payment credentials stored${NC}"

# Notifications
echo "Storing notification credentials..."
boas kv put secret/notifications/slack \
  webhook_url="$SLACK_WEBHOOK" \
  channel="#alerts" \
  username="Creative Platform"
echo -e "${GREEN}✅ Notification credentials stored${NC}"

# Cloud Services
echo "Storing cloud service credentials..."
boas kv put secret/cloud/temporal \
  namespace="creative-platform-prod.tmprl.cloud" \
  api_key="$TEMPORAL_API_KEY" \
  address="your-namespace.tmprl.cloud:7233"
echo -e "${GREEN}✅ Temporal Cloud credentials stored${NC}"

echo "Storing ClickHouse credentials..."
boas kv put secret/cloud/clickhouse \
  host="your-service.clickhouse.cloud" \
  port="8443" \
  user="default" \
  password="$CLICKHOUSE_PASSWORD" \
  database="metrics" \
  connection_string="https://default:$CLICKHOUSE_PASSWORD@your-service.clickhouse.cloud:8443/metrics"
echo -e "${GREEN}✅ ClickHouse credentials stored${NC}"

# SSL/TLS Certificates
echo "Storing SSL certificates..."
boas kv put secret/ssl/certificates \
  cert=@/etc/letsencrypt/live/agennext.com/fullchain.pem \
  key=@/etc/letsencrypt/live/agennext.com/privkey.pem \
  domain="agennext.com" \
  issuer="Let's Encrypt"
echo -e "${GREEN}✅ SSL certificates stored${NC}"

# API Keys
echo "Storing API keys..."
boas kv put secret/api/keys \
  production_api_key=$(openssl rand -base64 32) \
  staging_api_key=$(openssl rand -base64 32) \
  development_api_key=$(openssl rand -base64 32)
echo -e "${GREEN}✅ API keys stored${NC}"

# Environment Configuration
echo "Storing environment configuration..."
boas kv put secret/config/production \
  api_url="https://app.creative-platform.com" \
  web_url="https://creative-platform.com" \
  grafana_url="https://grafana.creative-platform.com" \
  prometheus_url="https://prometheus.creative-platform.com" \
  environment="production" \
  log_level="info" \
  debug="false"
echo -e "${GREEN}✅ Environment configuration stored${NC}"

echo ""
echo -e "${YELLOW}Step 4: Setting up access policies${NC}"
echo ""

# Create policy for deployment script
cat > /tmp/deploy-policy.hcl << 'EOF'
# Policy for deployment script
path "secret/data/vps/*" {
  capabilities = ["read", "list"]
}

path "secret/data/database/*" {
  capabilities = ["read", "list"]
}

path "secret/data/auth/*" {
  capabilities = ["read", "list"]
}

path "secret/data/liferay/*" {
  capabilities = ["read", "list"]
}

path "secret/data/redis/*" {
  capabilities = ["read", "list"]
}

path "secret/data/github/*" {
  capabilities = ["read", "list"]
}

path "secret/data/cloud/*" {
  capabilities = ["read", "list"]
}

path "secret/data/config/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/*" {
  capabilities = ["list"]
}
EOF

boas policy write deploy-policy /tmp/deploy-policy.hcl
echo -e "${GREEN}✅ Deploy policy created${NC}"

echo ""
echo -e "${YELLOW}Step 5: Creating deployment token${NC}"
echo ""

DEPLOY_TOKEN=$(boas token create -policy=deploy-policy -ttl=24h -format=json | jq -r '.auth.client_token')

echo "Deployment token created (expires in 24h):"
echo "  $DEPLOY_TOKEN"
echo ""

# Save for later use
cat > ~/.openbao/deploy-token << EOF
BOAS_ADDR=$BOAS_ADDR
BOAS_TOKEN=$DEPLOY_TOKEN
BOAS_NAMESPACE=$BOAS_NAMESPACE
EOF

chmod 600 ~/.openbao/deploy-token

echo -e "${GREEN}✅ Token saved to ~/.openbao/deploy-token${NC}"

echo ""
echo -e "${BLUE}=========================================="
echo "✅ OPENBAO SETUP COMPLETE"
echo "==========================================${NC}"
echo ""

echo -e "${YELLOW}Credentials stored:${NC}"
echo "  ✅ VPS (SSH, password, host)"
echo "  ✅ Database (PostgreSQL connection)"
echo "  ✅ Authentication (JWT secret)"
echo "  ✅ Liferay (API keys)"
echo "  ✅ Redis (cache password)"
echo "  ✅ GitHub (tokens, registry)"
echo "  ✅ Stripe (payment keys)"
echo "  ✅ Slack (webhooks)"
echo "  ✅ Temporal Cloud (API keys)"
echo "  ✅ ClickHouse (credentials)"
echo "  ✅ SSL/TLS (certificates)"
echo "  ✅ Environment config"
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Source deployment token: source ~/.openbao/deploy-token"
echo "  2. Update deploy script to use OpenBao: BOAS_TOKEN=... bash deploy-to-vps.sh"
echo "  3. Verify credentials: boas kv list secret/"
echo "  4. Rotate credentials periodically"
echo ""

echo -e "${YELLOW}Retrieve credentials in scripts:${NC}"
echo ""
echo "  # Get database password"
echo "  boas kv get -field=password secret/database/postgres"
echo ""
echo "  # Get all VPS creds"
echo "  boas kv get secret/vps/credentials"
echo ""
echo "  # Watch for changes"
echo "  boas kv get -format=json secret/database/postgres | jq '.data.data'"
echo ""
