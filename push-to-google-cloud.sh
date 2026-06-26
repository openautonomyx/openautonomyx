#!/bin/bash

# OpenAutonomyX - Push All Services to Google Cloud Artifact Registry
# Automated building and pushing to Google Cloud Platform

set -e

COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
NC='\033[0m'

PROJECT_ID="${1:-openautonomyx}"
REGION="${2:-us-central1}"
VERSION="${3:-1.0.0}"
DRY_RUN="${4:-false}"

REGISTRY="$REGION-docker.pkg.dev/$PROJECT_ID/openautonomyx-docker"

# Display banner
clear
echo -e "${COLOR_BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${COLOR_BLUE}║     🌩️  Push to Google Cloud Artifact Registry             ║${NC}"
echo -e "${COLOR_BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${COLOR_BLUE}Configuration:${NC}"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Registry: $REGISTRY"
echo "  Version: $VERSION"
echo "  Dry Run: $DRY_RUN"
echo ""

# Check gcloud
echo -e "${COLOR_YELLOW}Checking Google Cloud SDK...${NC}"
if ! command -v gcloud &> /dev/null; then
  echo -e "${COLOR_RED}❌ gcloud not installed${NC}"
  echo "Install: https://cloud.google.com/sdk/docs/install"
  exit 1
fi
echo -e "${COLOR_GREEN}✅ gcloud SDK installed${NC}\n"

# Check authentication
echo -e "${COLOR_YELLOW}Checking Google Cloud authentication...${NC}"
if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q .; then
  echo -e "${COLOR_RED}❌ Not authenticated with Google Cloud${NC}"
  echo -e "${COLOR_YELLOW}Logging in...${NC}"
  gcloud auth login
fi
ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format='value(account)')
echo -e "${COLOR_GREEN}✅ Authenticated as: $ACCOUNT${NC}\n"

# Set project
echo -e "${COLOR_YELLOW}Setting project...${NC}"
gcloud config set project $PROJECT_ID
echo -e "${COLOR_GREEN}✅ Project set to: $PROJECT_ID${NC}\n"

# Enable APIs
echo -e "${COLOR_YELLOW}Enabling required APIs...${NC}"
gcloud services enable artifactregistry.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable storage-api.googleapis.com
echo -e "${COLOR_GREEN}✅ APIs enabled${NC}\n"

# Check/Create repository
echo -e "${COLOR_YELLOW}Checking Artifact Registry repository...${NC}"
if ! gcloud artifacts repositories describe openautonomyx-docker --location=$REGION > /dev/null 2>&1; then
  echo -e "${COLOR_YELLOW}Creating repository...${NC}"
  gcloud artifacts repositories create openautonomyx-docker \
    --repository-format=docker \
    --location=$REGION \
    --description="OpenAutonomyX Docker Images"
  echo -e "${COLOR_GREEN}✅ Repository created${NC}"
else
  echo -e "${COLOR_GREEN}✅ Repository exists${NC}"
fi
echo ""

# Configure Docker authentication
echo -e "${COLOR_YELLOW}Configuring Docker authentication...${NC}"
gcloud auth configure-docker $REGION-docker.pkg.dev
echo -e "${COLOR_GREEN}✅ Docker authentication configured${NC}\n"

# Build and push function
build_and_push() {
  local service=$1
  local path=$2
  local port=$3

  if [ ! -d "$path" ]; then
    echo -e "${COLOR_YELLOW}⏭️  Skipping $service (path not found: $path)${NC}"
    return 0
  fi

  echo -e "${COLOR_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${COLOR_BLUE}Building & pushing: $service (port $port)${NC}"
  echo -e "${COLOR_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  if [ "$DRY_RUN" = "true" ]; then
    echo -e "${COLOR_YELLOW}[DRY RUN] Would build: $path${NC}"
    echo -e "${COLOR_YELLOW}[DRY RUN] Would push: $REGISTRY/$service:$VERSION${NC}"
    echo ""
    return 0
  fi

  # Build image
  echo -e "${COLOR_YELLOW}Building Docker image...${NC}"
  if docker build -t $REGISTRY/$service:$VERSION \
    -t $REGISTRY/$service:latest \
    --label "org.openautonomyx.service=$service" \
    --label "org.openautonomyx.version=$VERSION" \
    --label "org.openautonomyx.port=$port" \
    $path; then
    echo -e "${COLOR_GREEN}✅ Build successful${NC}"
  else
    echo -e "${COLOR_RED}❌ Build failed for $service${NC}"
    return 1
  fi

  # Push to Artifact Registry
  echo -e "${COLOR_YELLOW}Pushing to Google Artifact Registry...${NC}"
  if docker push $REGISTRY/$service:$VERSION; then
    echo -e "${COLOR_GREEN}✅ Pushed: $REGISTRY/$service:$VERSION${NC}"
  else
    echo -e "${COLOR_RED}❌ Push failed for $service:$VERSION${NC}"
    return 1
  fi

  if docker push $REGISTRY/$service:latest; then
    echo -e "${COLOR_GREEN}✅ Pushed: $REGISTRY/$service:latest${NC}"
  else
    echo -e "${COLOR_RED}❌ Push failed for $service:latest${NC}"
    return 1
  fi

  echo ""
}

# Track results
TOTAL=0
SUCCESSFUL=0
FAILED=0

# Core Services
echo -e "\n${COLOR_BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${COLOR_BLUE}📌 CORE SERVICES${NC}"
echo -e "${COLOR_BLUE}═══════════════════════════════════════════════════════════${NC}\n"

build_and_push "api-gateway" "services/api-gateway" "3000" && ((SUCCESSFUL++)) || ((FAILED++)); ((TOTAL++))
build_and_push "event-bus" "services/event-bus" "3001" && ((SUCCESSFUL++)) || ((FAILED++)); ((TOTAL++))

# Business Services
echo -e "\n${COLOR_BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${COLOR_BLUE}🎯 BUSINESS SERVICES${NC}"
echo -e "${COLOR_BLUE}═══════════════════════════════════════════════════════════${NC}\n"

build_and_push "content-management" "services/content-management" "3002" && ((SUCCESSFUL++)) || ((FAILED++)); ((TOTAL++))
build_and_push "skills" "services/skills" "3003" && ((SUCCESSFUL++)) || ((FAILED++)); ((TOTAL++))
build_and_push "tools" "services/tools" "3004" && ((SUCCESSFUL++)) || ((FAILED++)); ((TOTAL++))
build_and_push "analytics" "services/analytics" "3005" && ((SUCCESSFUL++)) || ((FAILED++)); ((TOTAL++))
build_and_push "optimization" "services/optimization" "3006" && ((SUCCESSFUL++)) || ((FAILED++)); ((TOTAL++))
build_and_push "design" "services/design" "3007" && ((SUCCESSFUL++)) || ((FAILED++)); ((TOTAL++))
build_and_push "features" "services/features" "3008" && ((SUCCESSFUL++)) || ((FAILED++)); ((TOTAL++))
build_and_push "blog" "services/blog" "3009" && ((SUCCESSFUL++)) || ((FAILED++)); ((TOTAL++))
build_and_push "integrations" "services/integrations" "3010" && ((SUCCESSFUL++)) || ((FAILED++)); ((TOTAL++))
build_and_push "formats" "services/formats" "3011" && ((SUCCESSFUL++)) || ((FAILED++)); ((TOTAL++))

# Support Services
echo -e "\n${COLOR_BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${COLOR_BLUE}🛠️  SUPPORT SERVICES${NC}"
echo -e "${COLOR_BLUE}═══════════════════════════════════════════════════════════${NC}\n"

build_and_push "nginx" "deployment/nginx" "80" && ((SUCCESSFUL++)) || ((FAILED++)); ((TOTAL++))
build_and_push "core-library" "core-library" "N/A" && ((SUCCESSFUL++)) || ((FAILED++)); ((TOTAL++))

# Summary
echo -e "\n${COLOR_BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${COLOR_BLUE}📊 SUMMARY${NC}"
echo -e "${COLOR_BLUE}═══════════════════════════════════════════════════════════${NC}\n"

echo "Total services: $TOTAL"
echo -e "${COLOR_GREEN}Successful: $SUCCESSFUL${NC}"
if [ $FAILED -gt 0 ]; then
  echo -e "${COLOR_RED}Failed: $FAILED${NC}"
fi

if [ $FAILED -eq 0 ]; then
  echo -e "\n${COLOR_GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${COLOR_GREEN}║  ✅ All services pushed to Google Cloud successfully!        ║${NC}"
  echo -e "${COLOR_GREEN}╚════════════════════════════════════════════════════════════╝${NC}"

  echo -e "\n${COLOR_BLUE}📍 View on Google Cloud Console:${NC}"
  echo "   https://console.cloud.google.com/artifacts/docker/$REGION/openautonomyx-docker?project=$PROJECT_ID"

  echo -e "\n${COLOR_BLUE}🐳 Pull any service:${NC}"
  echo "   docker pull $REGISTRY/[service-name]:$VERSION"

  echo -e "\n${COLOR_BLUE}☸️  Deploy to GKE:${NC}"
  echo "   gcloud container clusters create openautonomyx-prod --zone us-central1-a"
  echo "   kubectl apply -f k8s/"

  echo -e "\n${COLOR_BLUE}🚀 Deploy with Cloud Run:${NC}"
  echo "   gcloud run deploy blog-service \\"
  echo "     --image $REGISTRY/blog:$VERSION \\"
  echo "     --platform managed \\"
  echo "     --region $REGION"

  echo -e "\n${COLOR_BLUE}📊 View costs and usage:${NC}"
  echo "   https://console.cloud.google.com/billing/summary?project=$PROJECT_ID"

  exit 0
else
  echo -e "\n${COLOR_RED}❌ Some services failed to push${NC}"
  exit 1
fi
