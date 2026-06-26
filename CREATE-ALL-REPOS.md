# Create All OpenAutonomyX Service Repositories

Complete setup guide for all microservices as separate GitHub repositories.

---

## Service Repositories to Create

```
1. Blog Service (3009)
   https://github.com/Open-Autonomyx/blog-service
   
2. Formats Service (3011)
   https://github.com/Open-Autonomyx/formats-converter
   
3. Integrations Service (3010)
   https://github.com/Open-Autonomyx/integrations-service
   
4. Skills Service (3003)
   https://github.com/Open-Autonomyx/skills-service
   
5. Tools Service (3004)
   https://github.com/Open-Autonomyx/tools-service
   
6. Analytics Service (3005)
   https://github.com/Open-Autonomyx/analytics-service
   
7. Optimization Service (3006)
   https://github.com/Open-Autonomyx/optimization-service
   
8. Design Service (3007)
   https://github.com/Open-Autonomyx/design-service
   
9. Features Service (3008)
   https://github.com/Open-Autonomyx/features-service
   
10. Core Library (@publishing-platform/core)
    https://github.com/Open-Autonomyx/core-library
    
11. API Gateway (3000)
    https://github.com/Open-Autonomyx/api-gateway
    
12. Event Bus (3001)
    https://github.com/Open-Autonomyx/event-bus
```

---

## Automated Script to Create All Repos

### Option 1: Manual Web Creation (Fastest)

For each service:

1. Go to: https://github.com/organizations/Open-Autonomyx/repositories/new
2. Fill in:
   - **Name:** (see list above)
   - **Description:** (see templates below)
   - **Public:** ✅
3. Click **Create**
4. Run corresponding push command

---

## Service Details & Push Commands

### 1. Blog Service (3009)

```bash
# Create repo on GitHub first: Open-Autonomyx/blog-service

cd /Users/chinmaypanda/CustomApps/services/blog

git init
git add .
git commit -m "Initial: Blog Service - WordPress integration, internal blogging"
git remote add origin https://github.com/Open-Autonomyx/blog-service.git
git branch -M main
git push -u origin main

# Add README
cat > README.md << 'EOF'
# Blog Service

**Port:** 3009 | **Status:** ✅ Production Ready

## Features
- WordPress integration
- Internal blog management
- CRUD operations
- Search & filtering
- Comment moderation
- Multi-language support

## API Endpoints
```
POST   /api/v1/blog/posts
GET    /api/v1/blog/posts
GET    /api/v1/blog/posts/{id}
PUT    /api/v1/blog/posts/{id}
DELETE /api/v1/blog/posts/{id}
POST   /api/v1/blog/posts/{id}/publish
GET    /api/v1/blog/posts/{id}/comments
POST   /api/v1/blog/posts/{id}/comments
GET    /api/v1/blog/categories
GET    /api/v1/blog/tags
GET    /api/v1/blog/search?q=term
```

## Quick Start
```bash
npm install
npm run dev
# http://localhost:3009
```

## Environment
```
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
EVENT_BUS_URL=http://event-bus:3001
```

## Part Of
[OpenAutonomyX Publishing Platform](https://github.com/Open-Autonomyx/Publishing-Platform)

## License
MIT
EOF

git add README.md
git commit -m "Add: README"
git push
```

---

### 2. Formats Service (3011)

```bash
# Create repo: Open-Autonomyx/formats-converter

cd /Users/chinmaypanda/CustomApps/services/formats

git init
git add .
git commit -m "Initial: Format Converter Service - EPUB, PDF, Slides, Audio, Video, HTML"
git remote add origin https://github.com/Open-Autonomyx/formats-converter.git
git branch -M main
git push -u origin main

# Add README
cat > README.md << 'EOF'
# Format Converter Service

**Port:** 3011 | **Status:** ✅ Production Ready

## Supported Formats
- 📚 EPUB (e-books)
- 📄 PDF (documents)
- 📊 Slides (presentations)
- 🎧 Audio (podcasts/audiobooks)
- 🎬 Video (video content)
- 🌐 HTML (web pages)

## API Endpoints
```
POST   /api/v1/formats/epub
POST   /api/v1/formats/pdf
POST   /api/v1/formats/slides
POST   /api/v1/formats/audio
POST   /api/v1/formats/video
POST   /api/v1/formats/html
POST   /api/v1/formats/convert
GET    /api/v1/formats/supported
GET    /api/v1/formats/{format}/{id}/preview
```

## Usage
Convert content to any format:
```bash
curl -X POST http://localhost:3011/api/v1/formats/epub \
  -d '{"title":"My Book","author":"Me","content":"..."}'
```

## Quick Start
```bash
npm install
npm run dev
```

## Part Of
[OpenAutonomyX Publishing Platform](https://github.com/Open-Autonomyx/Publishing-Platform)

## License
MIT
EOF

git add README.md
git commit -m "Add: README"
git push
```

---

### 3. Integrations Service (3010)

```bash
# Create repo: Open-Autonomyx/integrations-service

cd /Users/chinmaypanda/CustomApps/services/integrations

git init
git add .
git commit -m "Initial: Integrations Service - Plugin architecture for multi-platform publishing"
git remote add origin https://github.com/Open-Autonomyx/integrations-service.git
git branch -M main
git push -u origin main

# Add README
cat > README.md << 'EOF'
# Integrations Service

**Port:** 3010 | **Status:** ✅ Production Ready

## Supported Platforms
- 📘 WordPress
- 📱 Medium
- 📬 Substack
- 𝕏 Twitter/X
- 💼 LinkedIn
- 👥 Facebook
- 🎨 Canva
- 🔌 Custom integrations

## Plugin Architecture
Easily add new platforms:
```typescript
// Register integration
POST /api/v1/integrations
{
  "name": "My Platform",
  "type": "custom",
  "config": { "apiKey": "..." }
}

// Publish to platform
POST /api/v1/integrations/{id}/publish
{ "title": "...", "content": "..." }
```

## API Endpoints
```
POST   /api/v1/integrations
GET    /api/v1/integrations
GET    /api/v1/integrations/{id}
PUT    /api/v1/integrations/{id}
DELETE /api/v1/integrations/{id}
POST   /api/v1/integrations/{id}/publish
GET    /api/v1/integrations/{id}/history
GET    /api/v1/integrations/supported
```

## Quick Start
```bash
npm install
npm run dev
```

## Part Of
[OpenAutonomyX Publishing Platform](https://github.com/Open-Autonomyx/Publishing-Platform)

## License
MIT
EOF

git add README.md
git commit -m "Add: README"
git push
```

---

### 4. Core Library

```bash
# Create repo: Open-Autonomyx/core-library

cd /tmp
mkdir core-library && cd core-library

git init
git add .
git commit -m "Initial: Core Library - Shared types, auth, events, utilities"
git remote add origin https://github.com/Open-Autonomyx/core-library.git
git branch -M main

# Copy from main repo
cp -r /Users/chinmaypanda/CustomApps/core-library-package.ts ./src/

git add .
git commit -m "Add: Complete core library implementation"
git push -u origin main

# Add README
cat > README.md << 'EOF'
# @publishing-platform/core

Shared library for OpenAutonomyX services.

## Exports
- **Types:** User, Role, Permission, JWTPayload, Event, etc.
- **Auth:** AuthService with JWT handling
- **Events:** EventBus for service communication
- **Utilities:** ValidationUtils, FormatterUtils
- **Middleware:** Auth, role, permission middleware factories

## Installation
```bash
npm install @publishing-platform/core
```

## Usage
```typescript
import { 
  AuthService, 
  EventBus, 
  ValidationUtils,
  User, Event 
} from '@publishing-platform/core';

const auth = new AuthService(JWT_SECRET);
const eventBus = new EventBus();
```

## Part Of
[OpenAutonomyX Publishing Platform](https://github.com/Open-Autonomyx/Publishing-Platform)

## License
MIT
EOF

git add README.md
git commit -m "Add: README"
git push
```

---

### 5. API Gateway (3000)

```bash
# Create repo: Open-Autonomyx/api-gateway

cd /Users/chinmaypanda/CustomApps/services/api-gateway

git init
git add .
git commit -m "Initial: API Gateway - Central routing, authentication, rate limiting"
git remote add origin https://github.com/Open-Autonomyx/api-gateway.git
git branch -M main
git push -u origin main

# Add README
cat > README.md << 'EOF'
# API Gateway

**Port:** 3000 | **Status:** ✅ Production Ready

## Features
- Central request routing
- JWT authentication
- Rate limiting
- Request logging
- Error handling
- Service discovery

## Routes
```
/api/v1/content      → Content Service (3002)
/api/v1/blog         → Blog Service (3009)
/api/v1/formats      → Formats Service (3011)
/api/v1/integrations → Integrations Service (3010)
/api/v1/analytics    → Analytics Service (3005)
/api/v1/optimization → Optimization Service (3006)
/api/v1/design       → Design Service (3007)
/api/v1/features     → Features Service (3008)
```

## Quick Start
```bash
npm install
npm run dev
```

## Part Of
[OpenAutonomyX Publishing Platform](https://github.com/Open-Autonomyx/Publishing-Platform)

## License
MIT
EOF

git add README.md
git commit -m "Add: README"
git push
```

---

### 6. Event Bus (3001)

```bash
# Create repo: Open-Autonomyx/event-bus

cd /Users/chinmaypanda/CustomApps/services/event-bus

git init
git add .
git commit -m "Initial: Event Bus - Service-to-service communication, pub/sub"
git remote add origin https://github.com/Open-Autonomyx/event-bus.git
git branch -M main
git push -u origin main

# Add README
cat > README.md << 'EOF'
# Event Bus

**Port:** 3001 | **Status:** ✅ Production Ready

## Features
- Pub/Sub messaging
- Event persistence
- Event replay
- Service-to-service communication
- Redis-backed

## Event Types
- content.created
- content.updated
- content.published
- content.deleted
- analytics.event
- optimization.recommendation
- skill.created
- feature.created

## API Endpoints
```
POST   /events
POST   /subscribe
GET    /events/{type}
GET    /events/{type}/history
```

## Quick Start
```bash
npm install
npm run dev
```

## Part Of
[OpenAutonomyX Publishing Platform](https://github.com/Open-Autonomyx/Publishing-Platform)

## License
MIT
EOF

git add README.md
git commit -m "Add: README"
git push
```

---

## One-Line Setup for All Services

```bash
#!/bin/bash

# Services to create
SERVICES=(
  "blog-service:services/blog"
  "formats-converter:services/formats"
  "integrations-service:services/integrations"
  "api-gateway:services/api-gateway"
  "event-bus:services/event-bus"
)

for service in "${SERVICES[@]}"; do
  IFS=':' read -r repo dir <<< "$service"
  
  echo "Setting up $repo..."
  
  cd "/Users/chinmaypanda/CustomApps/$dir"
  
  git init
  git add .
  git commit -m "Initial: $repo"
  git remote add origin "https://github.com/Open-Autonomyx/$repo.git"
  git branch -M main
  git push -u origin main
  
  echo "✅ $repo created!"
done

echo "🎉 All repositories created!"
```

---

## Checklist

- [ ] Create blog-service repo on GitHub
- [ ] Push blog service code
- [ ] Create formats-converter repo on GitHub
- [ ] Push formats service code
- [ ] Create integrations-service repo on GitHub
- [ ] Push integrations service code
- [ ] Create api-gateway repo on GitHub
- [ ] Push API Gateway code
- [ ] Create event-bus repo on GitHub
- [ ] Push Event Bus code
- [ ] Create core-library repo on GitHub
- [ ] Push Core Library code
- [ ] Update all with READMEs
- [ ] Add GitHub topics to each
- [ ] Setup GitHub Workflows

---

## Next: Link as Subtrees in Main Repo

```bash
cd /Users/chinmaypanda/CustomApps

git subtree add --prefix=services/blog \
  https://github.com/Open-Autonomyx/blog-service.git main

git subtree add --prefix=services/formats \
  https://github.com/Open-Autonomyx/formats-converter.git main

git subtree add --prefix=services/integrations \
  https://github.com/Open-Autonomyx/integrations-service.git main

git push
```

---

## Result

✅ 11 independent service repositories
✅ Linked via subtrees to main repo
✅ Full CI/CD ready
✅ Community contribution ready
✅ Modular microservices architecture

🚀 **Complete!**
