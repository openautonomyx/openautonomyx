# Push All Services to Docker Hub

**Complete guide for publishing 21 microservices to Docker Hub**

---

## Prerequisites

```bash
# 1. Create Docker Hub account
# Go to: https://hub.docker.com

# 2. Create organization
# Dashboard → Create Organization → open-autonomyx

# 3. Create access token
# Account Settings → Security → New Access Token
# Name: openautonomyx-automation
# Permissions: Read & Write
# Save the token

# 4. Login to Docker locally
docker login -u your-username -p your-access-token
# Or interactively: docker login
```

---

## Docker Hub Repositories Structure

**Organization:** `open-autonomyx`

**Repositories:** (23 total)

```
Infrastructure Services:
  open-autonomyx/postgres          (Database)
  open-autonomyx/redis             (Cache)
  open-autonomyx/elasticsearch     (Search)
  open-autonomyx/minio             (Storage)
  open-autonomyx/ollama            (Local LLM)

Core Services:
  open-autonomyx/api-gateway       (3000)
  open-autonomyx/event-bus         (3001)

Business Services:
  open-autonomyx/content-management (3002)
  open-autonomyx/skills            (3003)
  open-autonomyx/tools             (3004)
  open-autonomyx/analytics         (3005)
  open-autonomyx/optimization      (3006)
  open-autonomyx/design            (3007)
  open-autonomyx/features          (3008)
  open-autonomyx/blog              (3009)
  open-autonomyx/integrations      (3010)
  open-autonomyx/formats           (3011)

Support Services:
  open-autonomyx/liferay           (Portal UI)
  open-autonomyx/nginx             (Reverse proxy)

Libraries:
  open-autonomyx/core-library      (Shared code)
  open-autonomyx/publishing-platform (Main repo)
```

---

## Step 1: Create Dockerfiles for All Services

### API Gateway (3000)

```dockerfile
# services/api-gateway/Dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY src ./src

EXPOSE 3000

CMD ["node", "src/index.js"]
```

### Event Bus (3001)

```dockerfile
# services/event-bus/Dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY src ./src

EXPOSE 3001

CMD ["node", "src/index.js"]
```

### Content Management (3002)

```dockerfile
# services/content-management/Dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY src ./src
COPY database ./database

EXPOSE 3002

CMD ["node", "src/index.js"]
```

### Blog Service (3009)

```dockerfile
# services/blog/Dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY src ./src
COPY database ./database

EXPOSE 3009

CMD ["node", "src/index.js"]
```

### Formats Service (3011)

```dockerfile
# services/formats/Dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY src ./src

EXPOSE 3011

CMD ["node", "src/index.js"]
```

### Integrations Service (3010)

```dockerfile
# services/integrations/Dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY src ./src

EXPOSE 3010

CMD ["node", "src/index.js"]
```

### Core Library

```dockerfile
# core-library/Dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY src ./src

CMD ["npm", "publish"]
```

---

## Step 2: Build All Docker Images

```bash
#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

REGISTRY="open-autonomyx"
VERSION="1.0.0"

echo -e "${BLUE}Building all Docker images...${NC}\n"

# Infrastructure services (use official images)
echo "✅ Infrastructure services (using official images)"
echo "   - PostgreSQL"
echo "   - Redis"
echo "   - Elasticsearch"
echo "   - MinIO"
echo "   - Ollama"

# Core services
echo -e "\n${BLUE}Building core services...${NC}"

echo "Building API Gateway..."
docker build -t $REGISTRY/api-gateway:$VERSION \
  -t $REGISTRY/api-gateway:latest \
  services/api-gateway/
echo -e "${GREEN}✅ API Gateway${NC}"

echo "Building Event Bus..."
docker build -t $REGISTRY/event-bus:$VERSION \
  -t $REGISTRY/event-bus:latest \
  services/event-bus/
echo -e "${GREEN}✅ Event Bus${NC}"

# Business services
echo -e "\n${BLUE}Building business services...${NC}"

SERVICES=(
  "content-management:services/content-management"
  "skills:services/skills"
  "tools:services/tools"
  "analytics:services/analytics"
  "optimization:services/optimization"
  "design:services/design"
  "features:services/features"
  "blog:services/blog"
  "integrations:services/integrations"
  "formats:services/formats"
)

for service in "${SERVICES[@]}"; do
  IFS=':' read -r name dir <<< "$service"
  echo "Building $name..."
  docker build -t $REGISTRY/$name:$VERSION \
    -t $REGISTRY/$name:latest \
    $dir/
  echo -e "${GREEN}✅ $name${NC}"
done

echo -e "\n${BLUE}Building support services...${NC}"

echo "Building Nginx..."
docker build -t $REGISTRY/nginx:$VERSION \
  -t $REGISTRY/nginx:latest \
  deployment/nginx/
echo -e "${GREEN}✅ Nginx${NC}"

echo "Building Core Library..."
docker build -t $REGISTRY/core-library:$VERSION \
  -t $REGISTRY/core-library:latest \
  core-library/
echo -e "${GREEN}✅ Core Library${NC}"

echo -e "\n${GREEN}All images built successfully!${NC}"

# List all images
echo -e "\n${BLUE}Local Docker images:${NC}"
docker images | grep "open-autonomyx"
```

---

## Step 3: Push to Docker Hub

```bash
#!/bin/bash

REGISTRY="open-autonomyx"
VERSION="1.0.0"

echo "🔐 Docker Hub Login"
docker login

echo -e "\n📤 Pushing images to Docker Hub...\n"

# Infrastructure services
echo "Pushing infrastructure services..."
docker push $REGISTRY/postgres:$VERSION && echo "✅ PostgreSQL"
docker push $REGISTRY/redis:$VERSION && echo "✅ Redis"
docker push $REGISTRY/elasticsearch:$VERSION && echo "✅ Elasticsearch"
docker push $REGISTRY/minio:$VERSION && echo "✅ MinIO"
docker push $REGISTRY/ollama:$VERSION && echo "✅ Ollama"

# Core services
echo -e "\nPushing core services..."
docker push $REGISTRY/api-gateway:$VERSION && echo "✅ API Gateway"
docker push $REGISTRY/event-bus:$VERSION && echo "✅ Event Bus"

# Business services
echo -e "\nPushing business services..."

SERVICES=(
  "content-management"
  "skills"
  "tools"
  "analytics"
  "optimization"
  "design"
  "features"
  "blog"
  "integrations"
  "formats"
)

for service in "${SERVICES[@]}"; do
  docker push $REGISTRY/$service:$VERSION && echo "✅ $service"
done

# Support services
echo -e "\nPushing support services..."
docker push $REGISTRY/nginx:$VERSION && echo "✅ Nginx"
docker push $REGISTRY/core-library:$VERSION && echo "✅ Core Library"

echo -e "\n✅ All images pushed to Docker Hub!"
echo "📍 Registry: https://hub.docker.com/u/open-autonomyx"
```

---

## Step 4: Docker Hub Configuration

### Create README for each repository

```markdown
# OpenAutonomyX - [Service Name]

**Port:** XXXX | **Status:** ✅ Production Ready

## Overview
[Service description]

## Quick Start

### Pull image
\`\`\`bash
docker pull open-autonomyx/[service-name]:1.0.0
\`\`\`

### Run container
\`\`\`bash
docker run -d \\
  -p XXXX:XXXX \\
  -e DATABASE_URL=postgresql://... \\
  -e REDIS_URL=redis://... \\
  open-autonomyx/[service-name]:1.0.0
\`\`\`

### Environment Variables
- DATABASE_URL: PostgreSQL connection string
- REDIS_URL: Redis connection string
- EVENT_BUS_URL: Event Bus endpoint
- API_GATEWAY_URL: API Gateway endpoint

## Documentation
[Link to full documentation]

## Part Of
[OpenAutonomyX Publishing Platform](https://github.com/Open-Autonomyx/Publishing-Platform)

## License
MIT

## Support
- 📖 [Documentation](https://docs.publishing.openautonomyx.com)
- 💬 [Discord](https://discord.gg/openautonomyx)
- 🐛 [Issues](https://github.com/Open-Autonomyx/Publishing-Platform/issues)
```

---

## Automated Push Script

```bash
#!/bin/bash
# push-to-docker-hub.sh

set -e

COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_YELLOW='\033[1;33m'
NC='\033[0m'

REGISTRY="open-autonomyx"
VERSION="${1:-1.0.0}"
PUSH_LATEST="${2:-true}"

echo -e "${COLOR_BLUE}🐳 OpenAutonomyX Docker Hub Push${NC}\n"

# Check Docker login
echo "Checking Docker login..."
if ! docker info > /dev/null 2>&1; then
  echo -e "${COLOR_YELLOW}Not logged into Docker. Logging in...${NC}"
  docker login
fi

# Build and push function
build_and_push() {
  local service=$1
  local path=$2
  
  echo -e "\n${COLOR_BLUE}Building $service...${NC}"
  
  docker build -t $REGISTRY/$service:$VERSION $path
  
  if [ "$PUSH_LATEST" = "true" ]; then
    docker tag $REGISTRY/$service:$VERSION $REGISTRY/$service:latest
  fi
  
  echo -e "${COLOR_BLUE}Pushing $service to Docker Hub...${NC}"
  docker push $REGISTRY/$service:$VERSION
  
  if [ "$PUSH_LATEST" = "true" ]; then
    docker push $REGISTRY/$service:latest
  fi
  
  echo -e "${COLOR_GREEN}✅ $service pushed${NC}"
}

# Core services
echo -e "${COLOR_BLUE}Core Services${NC}"
build_and_push "api-gateway" "services/api-gateway"
build_and_push "event-bus" "services/event-bus"

# Business services
echo -e "\n${COLOR_BLUE}Business Services${NC}"
build_and_push "content-management" "services/content-management"
build_and_push "skills" "services/skills"
build_and_push "tools" "services/tools"
build_and_push "analytics" "services/analytics"
build_and_push "optimization" "services/optimization"
build_and_push "design" "services/design"
build_and_push "features" "services/features"
build_and_push "blog" "services/blog"
build_and_push "integrations" "services/integrations"
build_and_push "formats" "services/formats"

# Support services
echo -e "\n${COLOR_BLUE}Support Services${NC}"
build_and_push "nginx" "deployment/nginx"
build_and_push "core-library" "core-library"

echo -e "\n${COLOR_GREEN}╔════════════════════════════════════╗${NC}"
echo -e "${COLOR_GREEN}║  All services pushed to Docker Hub! ║${NC}"
echo -e "${COLOR_GREEN}╚════════════════════════════════════╝${NC}"

echo -e "\n${COLOR_BLUE}📍 View on Docker Hub:${NC}"
echo "https://hub.docker.com/u/open-autonomyx"

echo -e "\n${COLOR_BLUE}🐳 Pull any service:${NC}"
echo "docker pull open-autonomyx/[service-name]:$VERSION"

echo -e "\n${COLOR_BLUE}📖 Next: Deploy to Kubernetes${NC}"
echo "kubectl apply -f k8s/"
```

---

## Complete Docker Compose for Docker Hub Images

```yaml
# docker-compose.hub.yml
version: '3.9'

services:
  postgres:
    image: open-autonomyx/postgres:1.0.0
    environment:
      POSTGRES_DB: publishing_platform
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: your_password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: open-autonomyx/redis:1.0.0
    volumes:
      - redis_data:/data

  elasticsearch:
    image: open-autonomyx/elasticsearch:1.0.0
    environment:
      discovery.type: single-node

  minio:
    image: open-autonomyx/minio:1.0.0
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin

  ollama:
    image: open-autonomyx/ollama:1.0.0

  api-gateway:
    image: open-autonomyx/api-gateway:1.0.0
    ports:
      - "3000:3000"
    depends_on:
      - postgres
      - redis
      - event-bus

  event-bus:
    image: open-autonomyx/event-bus:1.0.0
    ports:
      - "3001:3001"
    depends_on:
      - redis

  content-management:
    image: open-autonomyx/content-management:1.0.0
    ports:
      - "3002:3002"
    depends_on:
      - postgres
      - api-gateway
      - event-bus

  blog:
    image: open-autonomyx/blog:1.0.0
    ports:
      - "3009:3009"
    depends_on:
      - postgres
      - api-gateway

  integrations:
    image: open-autonomyx/integrations:1.0.0
    ports:
      - "3010:3010"
    depends_on:
      - api-gateway
      - event-bus

  formats:
    image: open-autonomyx/formats:1.0.0
    ports:
      - "3011:3011"
    depends_on:
      - api-gateway

  nginx:
    image: open-autonomyx/nginx:1.0.0
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - api-gateway

volumes:
  postgres_data:
  redis_data:
```

---

## Quick Start: Push Everything Now

```bash
# 1. Login to Docker Hub
docker login

# 2. Build all services
cd /Users/chinmaypanda/CustomApps
./push-to-docker-hub.sh 1.0.0 true

# 3. Verify on Docker Hub
# Visit: https://hub.docker.com/u/open-autonomyx
```

---

## CI/CD Integration (GitHub Actions)

```yaml
# .github/workflows/docker-hub-push.yml
name: Push to Docker Hub

on:
  push:
    tags:
      - 'v*.*.*'

env:
  REGISTRY: open-autonomyx

jobs:
  push:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service:
          - api-gateway
          - event-bus
          - content-management
          - blog
          - integrations
          - formats
          - skills
          - tools
          - analytics
          - optimization
          - design
          - features
          - nginx

    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push ${{ matrix.service }}
        uses: docker/build-push-action@v4
        with:
          context: ./services/${{ matrix.service }}
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ matrix.service }}:${{ github.ref_name }}
            ${{ env.REGISTRY }}/${{ matrix.service }}:latest
```

---

## Summary

```
✅ 23 Docker images
✅ Automated building & pushing
✅ CI/CD integration ready
✅ Production-grade registry
✅ Easy deployment via Docker Compose
✅ Kubernetes ready

🚀 All services packaged & ready to ship!
```

---

🐳 **Let's Build & Push!**
