#!/bin/bash

# OpenAutonomyX - Push All Services to Docker Hub
# Automated building and pushing of all 21+ microservices

set -e

COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
NC='\033[0m'

REGISTRY="${DOCKER_REGISTRY:-open-autonomyx}"
VERSION="${1:-1.0.0}"
PUSH_LATEST="${2:-true}"
DRY_RUN="${3:-false}"

# Display banner
clear
echo -e "${COLOR_BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${COLOR_BLUE}║          🐳 OpenAutonomyX Docker Hub Push                   ║${NC}"
echo -e "${COLOR_BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${COLOR_BLUE}Configuration:${NC}"
echo "  Registry: $REGISTRY"
echo "  Version: $VERSION"
echo "  Push Latest: $PUSH_LATEST"
echo "  Dry Run: $DRY_RUN"
echo ""

# Check Docker daemon
echo -e "${COLOR_YELLOW}Checking Docker daemon...${NC}"
if ! docker info > /dev/null 2>&1; then
  echo -e "${COLOR_RED}❌ Docker daemon not running${NC}"
  exit 1
fi
echo -e "${COLOR_GREEN}✅ Docker daemon OK${NC}\n"

# Check Docker login
echo -e "${COLOR_YELLOW}Checking Docker login...${NC}"
if ! docker info | grep -q "Username"; then
  echo -e "${COLOR_YELLOW}⚠️  Not logged into Docker Hub. Please login:${NC}"
  docker login
  if [ $? -ne 0 ]; then
    echo -e "${COLOR_RED}❌ Docker login failed${NC}"
    exit 1
  fi
fi
echo -e "${COLOR_GREEN}✅ Docker authenticated${NC}\n"

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
    echo -e "${COLOR_YELLOW}[DRY RUN] Would tag: $REGISTRY/$service:$VERSION${NC}"
    if [ "$PUSH_LATEST" = "true" ]; then
      echo -e "${COLOR_YELLOW}[DRY RUN] Would tag: $REGISTRY/$service:latest${NC}"
    fi
    echo -e "${COLOR_YELLOW}[DRY RUN] Would push to Docker Hub${NC}\n"
    return 0
  fi

  # Build image
  echo -e "${COLOR_YELLOW}Building Docker image...${NC}"
  if docker build -t $REGISTRY/$service:$VERSION \
    --label "org.openautonomyx.service=$service" \
    --label "org.openautonomyx.version=$VERSION" \
    --label "org.openautonomyx.port=$port" \
    $path; then
    echo -e "${COLOR_GREEN}✅ Build successful${NC}"
  else
    echo -e "${COLOR_RED}❌ Build failed for $service${NC}"
    return 1
  fi

  # Tag latest
  if [ "$PUSH_LATEST" = "true" ]; then
    echo -e "${COLOR_YELLOW}Tagging as latest...${NC}"
    docker tag $REGISTRY/$service:$VERSION $REGISTRY/$service:latest
  fi

  # Push to Docker Hub
  echo -e "${COLOR_YELLOW}Pushing to Docker Hub...${NC}"
  if docker push $REGISTRY/$service:$VERSION; then
    echo -e "${COLOR_GREEN}✅ Pushed: $REGISTRY/$service:$VERSION${NC}"
  else
    echo -e "${COLOR_RED}❌ Push failed for $service:$VERSION${NC}"
    return 1
  fi

  if [ "$PUSH_LATEST" = "true" ]; then
    if docker push $REGISTRY/$service:latest; then
      echo -e "${COLOR_GREEN}✅ Pushed: $REGISTRY/$service:latest${NC}"
    else
      echo -e "${COLOR_RED}❌ Push failed for $service:latest${NC}"
      return 1
    fi
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
  echo -e "${COLOR_GREEN}║  ✅ All services pushed to Docker Hub successfully!          ║${NC}"
  echo -e "${COLOR_GREEN}╚════════════════════════════════════════════════════════════╝${NC}"

  echo -e "\n${COLOR_BLUE}📍 View on Docker Hub:${NC}"
  echo "   https://hub.docker.com/u/$REGISTRY"

  echo -e "\n${COLOR_BLUE}🐳 Pull any service:${NC}"
  echo "   docker pull $REGISTRY/[service-name]:$VERSION"

  echo -e "\n${COLOR_BLUE}🚀 Deploy with Docker Compose:${NC}"
  echo "   docker-compose -f docker-compose.hub.yml up -d"

  echo -e "\n${COLOR_BLUE}☸️  Deploy to Kubernetes:${NC}"
  echo "   kubectl apply -f k8s/services/"

  exit 0
else
  echo -e "\n${COLOR_RED}❌ Some services failed to push${NC}"
  exit 1
fi
