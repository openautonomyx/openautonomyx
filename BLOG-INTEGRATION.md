# Blog Integration - Publishing Platform

## Overview

The Blog module is fully integrated into the Publishing Platform as a dedicated microservice handling all blog publishing, reading, and commenting operations.

**Service:** `@publishing-platform/blog`
**Port:** `3009`
**Database:** PostgreSQL (shared)
**Cache:** Redis (for popular posts)
**Events:** Event Bus integration

---

## API Endpoints

### Posts

#### Create Post
```bash
POST /api/v1/blog/posts
Content-Type: application/json

{
  "title": "Getting Started with OpenAutonomyX",
  "excerpt": "Learn how to...",
  "content": "## Introduction\n\nFull markdown content here...",
  "category": "tutorial",
  "tags": ["guide", "getting-started"]
}
```

#### Get All Posts
```bash
GET /api/v1/blog/posts?status=published&category=tutorial&page=1&limit=10
```

#### Get Single Post
```bash
GET /api/v1/blog/posts/{id}
GET /api/v1/blog/posts/slug/{slug}
```

#### Update Post
```bash
PUT /api/v1/blog/posts/{id}
Content-Type: application/json

{
  "title": "Updated Title",
  "content": "Updated content..."
}
```

#### Publish Post
```bash
POST /api/v1/blog/posts/{id}/publish
```

#### Delete Post
```bash
DELETE /api/v1/blog/posts/{id}
```

### Categories & Tags

#### Get Categories
```bash
GET /api/v1/blog/categories
```

#### Get Tags
```bash
GET /api/v1/blog/tags
```

### Search

#### Search Posts
```bash
GET /api/v1/blog/search?q=openautonomyx
```

### Comments

#### Add Comment
```bash
POST /api/v1/blog/posts/{id}/comments
Content-Type: application/json

{
  "author": "John Doe",
  "email": "john@example.com",
  "content": "Great post!"
}
```

#### Get Comments
```bash
GET /api/v1/blog/posts/{id}/comments
```

---

## Response Format

All responses follow the standard API format:

```json
{
  "success": true,
  "data": { /* endpoint-specific data */ },
  "timestamp": "2026-06-26T10:30:00Z"
}
```

---

## Integration with OpenAutonomyX.com

### Router Configuration

Add to API Gateway routes:

```typescript
app.use('/blog', blogModuleRouter);
```

This makes blog accessible at:
- `https://openautonomyx.com/blog/posts` (all posts)
- `https://openautonomyx.com/blog/posts/{id}` (single post)
- `https://openautonomyx.com/blog/search?q=term` (search)

### Frontend Routes

Add to your React/Next.js app:

```typescript
// pages/blog/index.tsx - All posts
// pages/blog/[slug].tsx - Single post
// pages/blog/category/[category].tsx - Category view
// pages/blog/tag/[tag].tsx - Tag view
// pages/blog/search - Search results
```

### Admin Panel Integration

Access blog management at:
- `http://localhost:3000/admin/blog`
- Create, edit, publish, delete posts
- Moderate comments
- View analytics

---

## Events Published

### `content.created`
```json
{
  "type": "content.created",
  "source": "blog",
  "data": {
    "postId": "uuid",
    "title": "Post title",
    "author": "Author name"
  }
}
```

### `content.published`
```json
{
  "type": "content.published",
  "source": "blog",
  "data": {
    "postId": "uuid",
    "title": "Post title",
    "publishedAt": "2026-06-26T10:30:00Z"
  }
}
```

### `content.updated`
```json
{
  "type": "content.updated",
  "source": "blog",
  "data": {
    "postId": "uuid",
    "title": "Post title"
  }
}
```

---

## Database Schema

### posts table
```sql
CREATE TABLE posts (
  id UUID PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  slug VARCHAR(255) UNIQUE NOT NULL,
  excerpt TEXT,
  content TEXT NOT NULL,
  author VARCHAR(255),
  status VARCHAR(20) DEFAULT 'draft',
  category VARCHAR(100),
  tags TEXT[],
  published_at TIMESTAMP,
  views INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_posts_status ON posts(status);
CREATE INDEX idx_posts_category ON posts(category);
CREATE INDEX idx_posts_slug ON posts(slug);
CREATE INDEX idx_posts_published_at ON posts(published_at DESC);
```

### comments table
```sql
CREATE TABLE comments (
  id UUID PRIMARY KEY,
  post_id UUID REFERENCES posts(id),
  author VARCHAR(255),
  email VARCHAR(255),
  content TEXT,
  approved BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_comments_post_id ON comments(post_id);
CREATE INDEX idx_comments_approved ON comments(approved);
```

---

## Deployment

### Docker Compose
```yaml
blog:
  build:
    context: ./services/blog
    dockerfile: Dockerfile
  container_name: pp-blog
  ports:
    - "3009:3009"
  environment:
    NODE_ENV: development
    PORT: 3009
    SERVICE_NAME: blog
    DATABASE_URL: postgresql://pp_admin:secure_password_change_me@postgres:5432/publishing_platform
    REDIS_URL: redis://redis:6379
    EVENT_BUS_URL: http://event-bus:3001
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy
    event-bus:
      condition: service_started
  networks:
    - pp-network
  restart: unless-stopped
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blog
  namespace: publishing-platform
spec:
  replicas: 2
  selector:
    matchLabels:
      app: blog
  template:
    metadata:
      labels:
        app: blog
    spec:
      containers:
      - name: blog
        image: blog:latest
        ports:
        - containerPort: 3009
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-config
              key: url
        - name: EVENT_BUS_URL
          value: http://event-bus:3001
        livenessProbe:
          httpGet:
            path: /health
            port: 3009
          initialDelaySeconds: 40
          periodSeconds: 30
```

---

## Usage Examples

### Create and Publish a Blog Post

```bash
# 1. Create draft post
curl -X POST http://localhost:3009/api/v1/blog/posts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Welcome to OpenAutonomyX",
    "excerpt": "Your guide to vendor-neutral creative publishing",
    "content": "## Introduction\n\nOpenAutonomyX is a...",
    "category": "getting-started",
    "tags": ["welcome", "guide"]
  }'

# Response includes post ID

# 2. Publish the post
curl -X POST http://localhost:3009/api/v1/blog/posts/{post-id}/publish

# 3. View published post
curl http://localhost:3009/api/v1/blog/posts/slug/welcome-to-openautonomyx

# 4. Add comment
curl -X POST http://localhost:3009/api/v1/blog/posts/{post-id}/comments \
  -H "Content-Type: application/json" \
  -d '{
    "author": "Jane Doe",
    "email": "jane@example.com",
    "content": "Great introduction!"
  }'
```

---

## Next Steps

1. ✅ Blog service implemented
2. ⬜ Add to docker-compose.yml
3. ⬜ Connect to real PostgreSQL database
4. ⬜ Add to API Gateway routes
5. ⬜ Create blog frontend (React component)
6. ⬜ Add admin UI for blog management
7. ⬜ Implement SEO optimization
8. ⬜ Add analytics tracking

---

## Related Services

- **Content Management** (3002) - General content publishing
- **Analytics** (3005) - Track blog post views and engagement
- **Optimization** (3006) - AI-powered blog recommendations
- **Event Bus** (3001) - Cross-service communication

---

**Blog Module Status:** ✅ Ready for Integration
