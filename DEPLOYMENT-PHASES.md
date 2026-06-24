# 🚀 Phase-by-Phase Deployment Guide

**Complete step-by-step deployment from infrastructure to live platform**

---

## 📅 Deployment Timeline

```
Phase 0: Infrastructure (Day 1)
Phase 1: Core API (Day 2)
Phase 2: Database & Migrations (Day 3)
Phase 3: Liferay Integration (Day 4-5)
Phase 4: Approval Workflows (Day 6)
Phase 5: Cloud Services (Day 7)
Phase 6: Monitoring (Day 8)
Phase 7: Demo Site (Day 9)
Phase 8: Launch (Day 10)
```

---

## Phase 0: Infrastructure Setup (Day 1)

### Goal
Set up VPS, Docker, and basic networking

### Prerequisites
- AWS/DigitalOcean account
- Domain registered (creative-platform.com)
- GitHub repository set up
- SSL certificate ready

### Step-by-Step

#### 0.1: Provision VPS

```bash
# Using DigitalOcean
doctl compute droplet create creative-platform-prod \
  --region sfo3 \
  --size s-2vcpu-4gb \
  --image almalinux-x64 \
  --enable-monitoring \
  --enable-backups

# OR Using AWS
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.large \
  --key-name creative-platform \
  --security-groups default
```

#### 0.2: Initial Server Setup

```bash
# SSH into VPS
ssh root@agennext.com

# Update system
dnf update -y
dnf install -y curl wget git htop

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl start docker
systemctl enable docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verify
docker --version
docker-compose --version
```

#### 0.3: Configure Networking

```bash
# Configure firewall
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=3001/tcp
firewall-cmd --reload

# Create network
docker network create creative-network

# Configure DNS
# Point creative-platform.com → VPS IP
# A record: @ → VPS_IP
# CNAME: www → @
```

#### 0.4: SSL Certificate

```bash
# Install Certbot
dnf install -y certbot python3-certbot-nginx

# Generate certificate
certbot certonly --standalone -d creative-platform.com -d *.creative-platform.com

# Verify
ls -la /etc/letsencrypt/live/creative-platform.com/
```

### Verification

```bash
# Check Docker
docker ps
docker network ls

# Check networking
curl -I http://agennext.com
nslookup creative-platform.com

# Check storage
df -h
```

### Rollback
```bash
# Destroy VPS (if needed)
doctl compute droplet delete <droplet_id>
```

---

## Phase 1: Core API & Database (Day 2)

### Goal
Deploy PostgreSQL and Go API service

### Step-by-Step

#### 1.1: PostgreSQL Setup

```bash
# Pull PostgreSQL image
docker pull postgres:15-alpine

# Start PostgreSQL
docker run -d \
  --name postgres \
  --network creative-network \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=$(openssl rand -base64 32) \
  -v postgres_data:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:15-alpine

# Wait for startup
sleep 10

# Create database
docker exec postgres createdb -U postgres creative_platform
```

#### 1.2: Database Schema

```bash
# Copy schema file to VPS
scp db/schema.sql root@agennext.com:/tmp/

# Load schema
docker exec -i postgres psql -U postgres creative_platform < /tmp/schema.sql

# Verify
docker exec postgres psql -U postgres creative_platform -c "\dt"
```

#### 1.3: Deploy API Service

```bash
# Build Docker image
docker build -t creative-platform-api:v1.0 src/api/

# Push to GHCR
docker tag creative-platform-api:v1.0 ghcr.io/fractional-pm/creative-platform-api:v1.0
docker push ghcr.io/fractional-pm/creative-platform-api:v1.0

# Pull on VPS
docker pull ghcr.io/fractional-pm/creative-platform-api:v1.0

# Start API
docker run -d \
  --name api \
  --network creative-network \
  -e DATABASE_URL=postgres://postgres:password@postgres:5432/creative_platform \
  -e JWT_SECRET=$(openssl rand -base64 32) \
  -e API_PORT=3001 \
  -p 3001:3001 \
  ghcr.io/fractional-pm/creative-platform-api:v1.0
```

#### 1.4: Configure Nginx

```bash
# Create Nginx config
cat > /etc/nginx/conf.d/creative-platform.conf << 'EOF'
upstream api_backend {
    server localhost:3001;
}

server {
    listen 80;
    server_name creative-platform.com www.creative-platform.com;
    
    location / {
        proxy_pass http://api_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

# Start Nginx
systemctl start nginx
systemctl enable nginx
```

#### 1.5: Test API

```bash
# Health check
curl -i http://localhost:3001/health

# Should return:
# HTTP/1.1 200 OK
# {"status":"OK","timestamp":"2026-06-25T..."}
```

### Verification

```bash
# Check services
docker ps
systemctl status nginx

# Test endpoints
curl http://agennext.com/health
curl http://agennext.com/api/v1/

# Check logs
docker logs api
docker logs postgres
```

### Rollback

```bash
# Stop services
docker stop api postgres
docker rm api postgres

# Remove database
docker volume rm postgres_data
```

---

## Phase 2: Redis Cache (Day 2 - Evening)

### Goal
Add caching layer for performance

### Step-by-Step

```bash
# Start Redis
docker run -d \
  --name redis \
  --network creative-network \
  -p 6379:6379 \
  redis:7-alpine

# Test connection
docker exec redis redis-cli ping
# Should return: PONG

# Update API to use Redis
docker stop api
docker run -d \
  --name api \
  --network creative-network \
  -e DATABASE_URL=postgres://postgres:password@postgres:5432/creative_platform \
  -e REDIS_URL=redis://redis:6379 \
  -e JWT_SECRET=$(openssl rand -base64 32) \
  -e API_PORT=3001 \
  -p 3001:3001 \
  ghcr.io/fractional-pm/creative-platform-api:v1.0

# Verify
curl http://localhost:3001/health
```

### Verification

```bash
docker ps
docker logs api | grep -i redis
```

---

## Phase 3: Liferay DXP Integration (Day 4-5)

### Goal
Deploy Liferay and integrate with API

### Step-by-Step

#### 3.1: Deploy Liferay

```bash
# Pull Liferay image
docker pull liferay/dxp:latest

# Start Liferay
docker run -d \
  --name liferay \
  --network creative-network \
  -e LIFERAY_JPDA_ENABLED=false \
  -e LIFERAY_DATABASE_PREPARED_STATEMENT_CACHE_SIZE=500 \
  -v liferay_data:/opt/liferay \
  -p 8080:8080 \
  liferay/dxp:latest

# Wait for startup (5-10 minutes)
sleep 300

# Check logs
docker logs -f liferay | head -50
```

#### 3.2: Configure Liferay

```bash
# Get into Liferay container
docker exec -it liferay bash

# Create admin user
# Log in to http://localhost:8080
# Default: admin@liferay.com / admin
# Change password on first login

# Configure API connection
# Settings → Server Administration → Script

# Test connection from API
curl -X GET http://localhost:8080/api/jsonws/user/get-current-user
```

#### 3.3: Enable Liferay API

```bash
# Configure CORS in Liferay
docker exec liferay curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"corsAllowedHeaders":"*","corsAllowedOrigins":"*","corsAllowedMethods":"*"}' \
  http://localhost:8080/api/jsonws/portal-settings/update-settings
```

#### 3.4: Test Liferay Integration

```bash
# From API container, test Liferay
docker exec api curl -X GET http://liferay:8080/api/jsonws/user/get-current-user

# Should return user data
```

### Verification

```bash
# Liferay is running
curl http://localhost:8080

# API can communicate with Liferay
curl http://localhost:3001/api/v1/liferay/health
```

---

## Phase 4: Approval Workflows (Day 6)

### Goal
Deploy approval workflow system

### Step-by-Step

#### 4.1: Create Workflow Tables

```bash
# Run migrations
docker exec -i postgres psql -U postgres creative_platform << 'EOF'
-- Run SQL from ONBOARDING-FLOW.md
-- Create: tenants, tenant_users, onboarding_progress, 
--         content_approvals, approval_queue, approval_audit_log
EOF
```

#### 4.2: Deploy Approval Service

```bash
# Rebuild API with approval handlers
docker build -t creative-platform-api:v1.1 src/api/
docker tag creative-platform-api:v1.1 ghcr.io/fractional-pm/creative-platform-api:v1.1
docker push ghcr.io/fractional-pm/creative-platform-api:v1.1

# Stop old API
docker stop api
docker rm api

# Start new API
docker run -d \
  --name api \
  --network creative-network \
  -e DATABASE_URL=postgres://postgres:password@postgres:5432/creative_platform \
  -e REDIS_URL=redis://redis:6379 \
  -e LIFERAY_URL=http://liferay:8080 \
  -e LIFERAY_API_KEY=$(openssl rand -base64 32) \
  -e JWT_SECRET=$(openssl rand -base64 32) \
  -e API_PORT=3001 \
  -p 3001:3001 \
  ghcr.io/fractional-pm/creative-platform-api:v1.1
```

#### 4.3: Test Workflows

```bash
# Create test approval workflow
curl -X POST http://localhost:3001/api/v1/approvals/workflows \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Workflow",
    "stages": 2
  }'

# Submit content for approval
curl -X POST http://localhost:3001/api/v1/content/submit-approval \
  -H "Content-Type: application/json" \
  -d '{
    "content_id": "test-123",
    "reviewers": ["reviewer@example.com"]
  }'
```

### Verification

```bash
# Check workflow tables
docker exec postgres psql -U postgres creative_platform -c "SELECT * FROM content_approvals LIMIT 1"

# Check logs
docker logs api | grep -i approval
```

---

## Phase 5: Cloud Services Setup (Day 7)

### Goal
Configure Temporal Cloud and ClickHouse Cloud

### Step-by-Step

#### 5.1: Temporal Cloud

```bash
# Run setup script
./deploy/setup-temporal-cloud.sh

# Enter:
# - Namespace: creative-platform-prod.tmprl.cloud
# - API Key: (from Temporal Cloud dashboard)
# - TLS certificates: (optional)

# Verify
source .env.temporal
echo $TEMPORAL_NAMESPACE
```

#### 5.2: ClickHouse Cloud

```bash
# Run setup script
./deploy/setup-clickhouse-cloud.sh

# Enter:
# - Host: your-service.clickhouse.cloud
# - Port: 8443
# - Username: default
# - Password: (from ClickHouse Cloud)

# Verify
source .env.clickhouse
clickhouse-client --host $CLICKHOUSE_HOST --user $CLICKHOUSE_USER --password

# Initialize schema
./deploy/init-clickhouse.sh
```

#### 5.3: Update API Configuration

```bash
# Update API environment
docker stop api
docker run -d \
  --name api \
  --network creative-network \
  -e DATABASE_URL=postgres://postgres:password@postgres:5432/creative_platform \
  -e REDIS_URL=redis://redis:6379 \
  -e LIFERAY_URL=http://liferay:8080 \
  -e TEMPORAL_NAMESPACE=creative-platform-prod.tmprl.cloud \
  -e TEMPORAL_API_KEY=$(cat .env.temporal | grep TEMPORAL_API_KEY) \
  -e CLICKHOUSE_HOST=$(cat .env.clickhouse | grep CLICKHOUSE_HOST) \
  -e CLICKHOUSE_PASSWORD=$(cat .env.clickhouse | grep CLICKHOUSE_PASSWORD) \
  -e JWT_SECRET=$(openssl rand -base64 32) \
  -e API_PORT=3001 \
  -p 3001:3001 \
  ghcr.io/fractional-pm/creative-platform-api:v1.1
```

### Verification

```bash
# Test Temporal Cloud connection
curl http://localhost:3001/api/v1/temporal/health

# Test ClickHouse connection
curl http://localhost:3001/api/v1/clickhouse/health

# Check logs
docker logs api | grep -i temporal
docker logs api | grep -i clickhouse
```

---

## Phase 6: Monitoring Stack (Day 8)

### Goal
Deploy monitoring infrastructure

### Step-by-Step

#### 6.1: Deploy Monitoring Stack

```bash
# Copy docker-compose files
cp docker-compose.monitoring.yml docker-compose.yml deploy/

# Start monitoring services
docker-compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d

# Services starting:
# - Prometheus (9090)
# - Grafana (3000)
# - Loki (3100)
# - Promtail (9080)
# - Alertmanager (9093)
# - ClickHouse (8123)
# - Cortex (9009)

# Wait for startup
sleep 30
```

#### 6.2: Configure Prometheus

```bash
# Verify Prometheus is scraping
curl http://localhost:9090/api/v1/targets

# Should show all services as "UP"
```

#### 6.3: Configure Grafana

```bash
# Access Grafana
curl http://localhost:3000

# Default: admin / admin
# Change password

# Add data sources:
# 1. Prometheus: http://prometheus:9090
# 2. Loki: http://loki:3100
# 3. ClickHouse: host:8123

# Create dashboards
# - API Performance
# - Resource Usage
# - Error Tracking
```

#### 6.4: Configure Alerts

```bash
# Update alertmanager config
cat > deploy/alertmanager.yml << 'EOF'
# [alertmanager config from MONITORING-24-7.md]
EOF

# Reload alertmanager
docker exec alertmanager alertmanager --reload
```

### Verification

```bash
# Check all services
docker ps | grep -E "prometheus|grafana|loki|alertmanager"

# Test endpoints
curl http://localhost:9090/api/v1/query?query=up
curl http://localhost:3000
curl http://localhost:3100/ready
curl http://localhost:9093/-/healthy
```

---

## Phase 7: Demo Site (Day 9)

### Goal
Deploy public marketing website

### Step-by-Step

#### 7.1: Build Demo Site

```bash
# Install dependencies
cd src/demo-site
npm install

# Build for production
npm run build

# Test locally
npm start
# Visit http://localhost:3000
```

#### 7.2: Deploy to Vercel

```bash
# Install Vercel CLI
npm install -g vercel

# Login
vercel login

# Deploy
vercel --prod

# URL: https://creative-platform.com
```

#### 7.3: Configure Demo Environment

```bash
# Create demo tenant
curl -X POST http://api:3001/api/v1/onboarding/signup \
  -H "Content-Type: application/json" \
  -d '{
    "company_name": "Demo Company",
    "email": "demo@creative-platform.com",
    "plan": "professional"
  }'

# Get demo tenant ID
DEMO_TENANT_ID="..." # From response

# Create demo users
curl -X POST http://api:3001/api/v1/onboarding/$DEMO_TENANT_ID/users \
  -d '{
    "email": "reviewer@creative-platform.com",
    "role": "reviewer"
  }'
```

#### 7.4: Setup DNS

```bash
# Point domains to services
# creative-platform.com → Vercel (website)
# app.creative-platform.com → VPS (API)
# demo.creative-platform.com → VPS (demo)
# api.creative-platform.com → VPS (API)
# docs.creative-platform.com → Vercel (docs)

# DNS Records:
# CNAME: creative-platform.com → vercel.com
# CNAME: app → api.creative-platform.com
# CNAME: demo → api.creative-platform.com
# CNAME: docs → vercel.com
```

### Verification

```bash
# Test website
curl https://creative-platform.com

# Test demo environment
curl https://demo.creative-platform.com/api/v1/health

# Test API
curl https://app.creative-platform.com/health

# Check DNS
nslookup creative-platform.com
```

---

## Phase 8: Launch (Day 10)

### Goal
Go live with full platform

### Step-by-Step

#### 8.1: Pre-Launch Checklist

```bash
# ✅ API health
curl https://app.creative-platform.com/health

# ✅ Website live
curl https://creative-platform.com

# ✅ Demo accessible
curl https://demo.creative-platform.com

# ✅ Liferay running
curl http://localhost:8080

# ✅ Database healthy
docker exec postgres pg_isready

# ✅ Monitoring active
curl http://localhost:3000  # Grafana
curl http://localhost:9090  # Prometheus

# ✅ All services in Docker
docker ps | wc -l  # Should see 10+ services

# ✅ Backups configured
curl https://api.creative-platform.com/health/backup

# ✅ SSL certificates valid
openssl s_client -connect creative-platform.com:443 | grep "Not After"
```

#### 8.2: Load Testing

```bash
# Install load testing tool
npm install -g autocannon

# Test API endpoints
autocannon https://app.creative-platform.com/api/v1/content \
  --connections 100 \
  --duration 60 \
  --requests 1000

# Should handle 100 concurrent connections
# P95 latency < 200ms
# Error rate < 0.1%
```

#### 8.3: Security Audit

```bash
# Run security scan
docker run --rm \
  -v $(pwd):/code \
  aquasec/trivy image ghcr.io/fractional-pm/creative-platform-api:v1.1

# Check for vulnerabilities
# Should show: 0 CRITICAL, minimal HIGH
```

#### 8.4: Announce Launch

```bash
# Send launch email
# Post on social media
# Notify beta users
# Blog announcement

# Email template:
# Subject: Creative Platform is Live! 🚀
# Body: 
#   We're thrilled to announce that Creative Platform is now live!
#   
#   Get started:
#   1. Visit creative-platform.com
#   2. Try the live demo
#   3. Start your free 14-day trial
#   
#   Questions? Contact support@creative-platform.com
```

#### 8.5: Monitor Launch

```bash
# Watch metrics in real-time
open http://localhost:3000  # Grafana

# Tail logs
docker logs -f api
docker logs -f liferay
docker logs -f postgres

# Monitor errors
curl http://localhost:9093  # Alertmanager

# Check sign-ups
docker exec postgres psql -U postgres creative_platform \
  -c "SELECT COUNT(*) FROM tenants WHERE created_at > NOW() - INTERVAL '24 hours'"
```

### Verification

```bash
# All systems operational
echo "✅ Phase 8: Launch Complete"

# Expected state:
# - API: 200 OK on all endpoints
# - Website: Fully accessible
# - Demo: Live and working
# - Database: Healthy and backed up
# - Monitoring: All alerts green
# - Services: 12/12 running
# - Uptime: 99.9%
# - Latency: P95 < 200ms
# - Error Rate: < 0.1%
```

---

## 🔄 Rollback Procedures

### If Phase Fails

#### Quick Rollback
```bash
# Stop all services
docker-compose down

# Restore from backup
docker-compose up -d postgres
# Restore latest database backup

# Restart services
docker-compose up -d
```

#### Full Rollback to Previous Version
```bash
# Stop current version
docker stop api
docker rm api

# Start previous version
docker run -d \
  --name api \
  --network creative-network \
  -e DATABASE_URL=postgres://... \
  ghcr.io/fractional-pm/creative-platform-api:v1.0

# Verify
curl http://localhost:3001/health
```

---

## 📊 Phase Success Criteria

| Phase | Success Criteria | Status |
|-------|-----------------|--------|
| 0 | VPS running, Docker installed, networking working | ✅ |
| 1 | API responds to health check | ✅ |
| 2 | Database contains schema, tables created | ✅ |
| 3 | Liferay running, API can connect | ✅ |
| 4 | Approval workflows functional, endpoints working | ✅ |
| 5 | Temporal Cloud and ClickHouse Cloud connected | ✅ |
| 6 | Prometheus, Grafana, Alertmanager operational | ✅ |
| 7 | Website live, demo accessible, DNS configured | ✅ |
| 8 | Platform live, load tests pass, 0 critical alerts | ✅ |

---

## 🎯 Total Deployment Time

**~2-3 weeks** for full production deployment

- Phase 0-2: Days 1-3 (infrastructure + API)
- Phase 3: Days 4-5 (Liferay setup)
- Phase 4: Day 6 (workflows)
- Phase 5: Day 7 (cloud services)
- Phase 6: Day 8 (monitoring)
- Phase 7-8: Days 9-10 (website + launch)

**With experienced DevOps team:** 5-7 days  
**With beginner:** 2-3 weeks

---

## 📋 Deployment Commands Reference

```bash
# Phase 0: Infrastructure
./deploy/setup-vps.sh

# Phase 1-2: API & Database
docker-compose up -d postgres api redis

# Phase 3: Liferay
docker-compose up -d liferay

# Phase 4: Workflows
docker build -t creative-platform-api:v1.1 src/api/
docker-compose up -d api

# Phase 5: Cloud
./deploy/setup-temporal-cloud.sh
./deploy/setup-clickhouse-cloud.sh

# Phase 6: Monitoring
docker-compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d

# Phase 7: Demo Site
vercel --prod

# Phase 8: Launch
# Open https://creative-platform.com
```

---

**Status:** ✅ READY FOR PHASE-BY-PHASE DEPLOYMENT
