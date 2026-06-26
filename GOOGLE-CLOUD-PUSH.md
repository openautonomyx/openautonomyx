# Push Docker Images to Google Cloud Artifact Registry

**Complete guide for publishing to Google Cloud Platform**

---

## Prerequisites

```bash
# 1. Create Google Cloud Project
# https://console.cloud.google.com/projectcreate

# 2. Install Google Cloud CLI
# macOS:
brew install google-cloud-sdk

# Linux:
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# 3. Initialize Cloud SDK
gcloud init
gcloud auth login

# 4. Set your project
PROJECT_ID="openautonomyx"
gcloud config set project $PROJECT_ID
```

---

## Setup Google Artifact Registry

### Step 1: Enable APIs

```bash
# Enable required APIs
gcloud services enable artifactregistry.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable storage-api.googleapis.com
```

### Step 2: Create Artifact Registry Repositories

```bash
# Set variables
PROJECT_ID="openautonomyx"
REGION="us-central1"
REGISTRY_NAME="openautonomyx-docker"

# Create Docker repository
gcloud artifacts repositories create $REGISTRY_NAME \
  --repository-format=docker \
  --location=$REGION \
  --description="OpenAutonomyX Docker Images"

# Verify
gcloud artifacts repositories list --location=$REGION
```

### Step 3: Configure Docker Authentication

```bash
# Configure Docker to authenticate with Artifact Registry
gcloud auth configure-docker $REGION-docker.pkg.dev

# Verify authentication
docker login -u _json_key --password-stdin $REGION-docker.pkg.dev < ~/.config/gcloud/application_default_credentials.json
```

---

## Push to Google Artifact Registry

### Automated Script

```bash
#!/bin/bash
# push-to-google-cloud.sh

set -e

COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
NC='\033[0m'

PROJECT_ID="${1:-openautonomyx}"
REGION="${2:-us-central1}"
VERSION="${3:-1.0.0}"

REGISTRY="$REGION-docker.pkg.dev/$PROJECT_ID/openautonomyx-docker"

echo -e "${COLOR_BLUE}🐳 Pushing to Google Artifact Registry${NC}\n"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Registry: $REGISTRY"
echo ""

# Check gcloud auth
echo -e "${COLOR_YELLOW}Checking Google Cloud authentication...${NC}"
if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q .; then
  echo -e "${COLOR_RED}❌ Not authenticated with Google Cloud${NC}"
  gcloud auth login
fi
echo -e "${COLOR_GREEN}✅ Google Cloud authenticated${NC}\n"

# Configure Docker auth
echo -e "${COLOR_YELLOW}Configuring Docker authentication...${NC}"
gcloud auth configure-docker $REGION-docker.pkg.dev
echo -e "${COLOR_GREEN}✅ Docker configured${NC}\n"

# Build and push function
build_and_push() {
  local service=$1
  local path=$2

  if [ ! -d "$path" ]; then
    echo -e "${COLOR_YELLOW}⏭️  Skipping $service (path not found)${NC}"
    return 0
  fi

  echo -e "${COLOR_BLUE}Building $service...${NC}"
  docker build -t $REGISTRY/$service:$VERSION $path || return 1
  docker tag $REGISTRY/$service:$VERSION $REGISTRY/$service:latest

  echo -e "${COLOR_BLUE}Pushing $service...${NC}"
  docker push $REGISTRY/$service:$VERSION || return 1
  docker push $REGISTRY/$service:latest || return 1

  echo -e "${COLOR_GREEN}✅ $service pushed${NC}\n"
}

# Push all services
echo -e "${COLOR_BLUE}Core Services${NC}"
build_and_push "api-gateway" "services/api-gateway"
build_and_push "event-bus" "services/event-bus"

echo -e "${COLOR_BLUE}Business Services${NC}"
build_and_push "content-management" "services/content-management"
build_and_push "blog" "services/blog"
build_and_push "integrations" "services/integrations"
build_and_push "formats" "services/formats"
build_and_push "analytics" "services/analytics"
build_and_push "optimization" "services/optimization"
build_and_push "design" "services/design"
build_and_push "features" "services/features"
build_and_push "skills" "services/skills"
build_and_push "tools" "services/tools"

echo -e "${COLOR_BLUE}Support Services${NC}"
build_and_push "nginx" "deployment/nginx"
build_and_push "core-library" "core-library"

echo -e "\n${COLOR_GREEN}✅ All services pushed to Google Artifact Registry${NC}"
echo "📍 View: https://console.cloud.google.com/artifacts/docker/$REGION/openautonomyx-docker"
```

---

## Google Cloud Storage (GCS) for Content

### Setup Cloud Storage Buckets

```bash
#!/bin/bash

PROJECT_ID="openautonomyx"
REGION="us-central1"

echo "Creating Cloud Storage buckets..."

# Main content bucket
gsutil mb -l $REGION gs://$PROJECT_ID-content/
gsutil versioning set on gs://$PROJECT_ID-content/

# Backups bucket
gsutil mb -l $REGION gs://$PROJECT_ID-backups/
gsutil lifecycle set - gs://$PROJECT_ID-backups/ << 'EOF'
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 90}
      }
    ]
  }
}
EOF

# Logs bucket
gsutil mb -l $REGION gs://$PROJECT_ID-logs/
gsutil lifecycle set - gs://$PROJECT_ID-logs/ << 'EOF'
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 30}
      }
    ]
  }
}
EOF

echo "✅ Buckets created successfully"
gsutil ls
```

---

## Configure Services for Google Cloud

### Update Environment Variables

```bash
# .env.google-cloud
PROJECT_ID=openautonomyx
GCP_REGION=us-central1
GCP_ARTIFACT_REGISTRY=us-central1-docker.pkg.dev/openautonomyx/openautonomyx-docker

# Storage
GCS_CONTENT_BUCKET=openautonomyx-content
GCS_BACKUPS_BUCKET=openautonomyx-backups
GCS_LOGS_BUCKET=openautonomyx-logs

# Database
CLOUD_SQL_CONNECTION_NAME=openautonomyx:us-central1:postgres
DATABASE_URL=postgresql://postgres:password@/publishing_platform

# Cache
REDIS_HOST=openautonomyx-redis.c.openautonomyx.internal
REDIS_PORT=6379

# Search
ELASTICSEARCH_HOST=openautonomyx-elasticsearch.c.openautonomyx.internal
ELASTICSEARCH_PORT=9200
```

### Update docker-compose for Google Cloud

```yaml
version: '3.9'

services:
  api-gateway:
    image: us-central1-docker.pkg.dev/openautonomyx/openautonomyx-docker/api-gateway:1.0.0
    environment:
      GCS_CONTENT_BUCKET: openautonomyx-content
      DATABASE_URL: postgresql://postgres:${DB_PASSWORD}@cloudsql-proxy:5432/publishing_platform
      REDIS_HOST: redis
    depends_on:
      - cloudsql-proxy
      - redis

  cloudsql-proxy:
    image: gcr.io/cloud-sql-docker/cloud-sql-proxy:2.0
    command:
      - "openautonomyx:us-central1:postgres"
    environment:
      GOOGLE_APPLICATION_CREDENTIALS: /secrets/sa-key.json
    volumes:
      - ./sa-key.json:/secrets/sa-key.json:ro

  redis:
    image: us-central1-docker.pkg.dev/openautonomyx/openautonomyx-docker/redis:1.0.0

  content-management:
    image: us-central1-docker.pkg.dev/openautonomyx/openautonomyx-docker/content-management:1.0.0
    environment:
      GCS_BUCKET: openautonomyx-content
      DATABASE_URL: postgresql://postgres:${DB_PASSWORD}@cloudsql-proxy:5432/publishing_platform
    depends_on:
      - cloudsql-proxy
      - api-gateway
```

---

## Deploy to Google Cloud Run

### Docker Image to Cloud Run

```bash
#!/bin/bash

SERVICE_NAME=$1
IMAGE=$2
PROJECT_ID="openautonomyx"
REGION="us-central1"

gcloud run deploy $SERVICE_NAME \
  --image $IMAGE \
  --platform managed \
  --region $REGION \
  --project $PROJECT_ID \
  --memory 512Mi \
  --cpu 1 \
  --timeout 300 \
  --set-env-vars="DATABASE_URL=postgresql://...,GCS_BUCKET=openautonomyx-content" \
  --allow-unauthenticated
```

### Example: Deploy Blog Service

```bash
gcloud run deploy blog-service \
  --image us-central1-docker.pkg.dev/openautonomyx/openautonomyx-docker/blog:1.0.0 \
  --platform managed \
  --region us-central1 \
  --memory 512Mi \
  --cpu 1 \
  --set-env-vars="DATABASE_URL=postgresql://...,EVENT_BUS_URL=https://event-bus.openautonomyx.com" \
  --allow-unauthenticated
```

---

## Deploy to Google Kubernetes Engine (GKE)

### Create GKE Cluster

```bash
#!/bin/bash

CLUSTER_NAME="openautonomyx-prod"
REGION="us-central1"
ZONE="us-central1-a"

# Create cluster
gcloud container clusters create $CLUSTER_NAME \
  --zone $ZONE \
  --num-nodes 3 \
  --machine-type n1-standard-2 \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 10 \
  --enable-stackdriver-kubernetes

# Get credentials
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE

# Create namespace
kubectl create namespace openautonomyx
kubectl config set-context --current --namespace=openautonomyx
```

### Kubernetes Deployment Manifest

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blog-service
  namespace: openautonomyx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: blog
  template:
    metadata:
      labels:
        app: blog
    spec:
      serviceAccountName: blog-sa
      containers:
      - name: blog
        image: us-central1-docker.pkg.dev/openautonomyx/openautonomyx-docker/blog:1.0.0
        ports:
        - containerPort: 3009
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: blog-secrets
              key: database-url
        - name: GCS_BUCKET
          value: openautonomyx-content
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
          limits:
            cpu: 500m
            memory: 1Gi
        livenessProbe:
          httpGet:
            path: /health
            port: 3009
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3009
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: blog-service
  namespace: openautonomyx
spec:
  selector:
    app: blog
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3009
  type: LoadBalancer
```

### Deploy to GKE

```bash
# Create secrets
kubectl create secret generic blog-secrets \
  --from-literal=database-url="postgresql://postgres:password@cloudsql-proxy:5432/publishing_platform"

# Apply manifests
kubectl apply -f k8s/blog-deployment.yaml
kubectl apply -f k8s/api-gateway-deployment.yaml
kubectl apply -f k8s/event-bus-deployment.yaml

# Check deployment
kubectl get deployments
kubectl get pods
kubectl get services

# Monitor logs
kubectl logs -l app=blog -f
```

---

## CI/CD with Google Cloud Build

### cloudbuild.yaml

```yaml
steps:
  # Build Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPOSITORY}/${_SERVICE}:${SHORT_SHA}'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPOSITORY}/${_SERVICE}:latest'
      - '-f'
      - 'services/${_SERVICE}/Dockerfile'
      - 'services/${_SERVICE}/'

  # Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPOSITORY}/${_SERVICE}:${SHORT_SHA}'

  # Deploy to GKE
  - name: 'gcr.io/cloud-builders/gke-deploy'
    args:
      - run
      - --filename=k8s/
      - --image=${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPOSITORY}/${_SERVICE}:${SHORT_SHA}
      - --location=${_CLUSTER_ZONE}
      - --cluster=${_CLUSTER_NAME}
      - --namespace=openautonomyx

substitutions:
  _REGION: 'us-central1'
  _REPOSITORY: 'openautonomyx-docker'
  _SERVICE: 'api-gateway'
  _CLUSTER_NAME: 'openautonomyx-prod'
  _CLUSTER_ZONE: 'us-central1-a'

images:
  - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPOSITORY}/${_SERVICE}:${SHORT_SHA}'
  - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPOSITORY}/${_SERVICE}:latest'

options:
  machineType: 'N1_HIGHCPU_8'
  logging: CLOUD_LOGGING_ONLY
```

---

## Quick Start: Push to Google Cloud

```bash
# 1. Setup project
export PROJECT_ID="openautonomyx"
gcloud config set project $PROJECT_ID
gcloud auth login

# 2. Enable APIs
gcloud services enable artifactregistry.googleapis.com containerregistry.googleapis.com

# 3. Create repository
gcloud artifacts repositories create openautonomyx-docker \
  --repository-format=docker \
  --location=us-central1

# 4. Configure Docker auth
gcloud auth configure-docker us-central1-docker.pkg.dev

# 5. Push images
cd /Users/chinmaypanda/CustomApps
./push-to-google-cloud.sh openautonomyx us-central1 1.0.0

# 6. View in console
open "https://console.cloud.google.com/artifacts/docker/us-central1/openautonomyx-docker"
```

---

## Google Cloud Cost Optimization

```bash
# Set up billing alerts
gcloud billing budgets create \
  --billing-account=$BILLING_ACCOUNT_ID \
  --display-name="OpenAutonomyX Monthly Budget" \
  --budget-amount=1000 \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=100

# Monitor costs
gcloud billing accounts list
gcloud billing budgets list --billing-account=$BILLING_ACCOUNT_ID

# Set resource limits in GKE
kubectl set resources deployment api-gateway \
  --limits=cpu=500m,memory=1Gi \
  --requests=cpu=250m,memory=512Mi
```

---

## Summary

```
✅ Google Artifact Registry setup
✅ Docker images pushed to GCP
✅ Cloud Storage buckets configured
✅ GKE cluster ready
✅ Cloud Run deployments ready
✅ Cloud Build CI/CD configured
✅ Cost monitoring enabled

🚀 Production-ready on Google Cloud!
```

---

**Deploy command:**
```bash
./push-to-google-cloud.sh openautonomyx us-central1 1.0.0
```
