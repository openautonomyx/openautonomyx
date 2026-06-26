import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import { AuthService, EventBus, ValidationUtils, FormatterUtils } from '@publishing-platform/core';
import { v4 as uuid } from 'uuid';

const app = express();
const PORT = process.env.PORT || 3009;
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';

const auth = new AuthService(JWT_SECRET);
const eventBus = new EventBus();

// Types
interface BlogPost {
  id: string;
  title: string;
  slug: string;
  excerpt: string;
  content: string;
  author: string;
  status: 'draft' | 'published' | 'archived';
  tags: string[];
  category: string;
  publishedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
  views: number;
}

interface BlogComment {
  id: string;
  postId: string;
  author: string;
  email: string;
  content: string;
  approved: boolean;
  createdAt: Date;
}

// In-memory storage (replace with database)
const posts: Map<string, BlogPost> = new Map();
const comments: Map<string, BlogComment> = new Map();

// Middleware
app.use(cors());
app.use(express.json());

app.use((req: Request, res: Response, next: NextFunction) => {
  console.log(`[Blog] ${req.method} ${req.path}`);
  next();
});

// Health check
app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', service: 'blog', timestamp: new Date() });
});

// Create blog post
app.post('/api/v1/blog/posts', (req: Request, res: Response) => {
  try {
    const { title, excerpt, content, category, tags } = req.body;

    if (!title || !content) {
      return res.status(400).json({ error: 'Title and content required' });
    }

    const slug = title.toLowerCase().replace(/\s+/g, '-').replace(/[^\w-]/g, '');
    const post: BlogPost = {
      id: uuid(),
      title,
      slug,
      excerpt: excerpt || content.substring(0, 150),
      content,
      author: 'system',
      status: 'draft',
      tags: tags || [],
      category: category || 'general',
      createdAt: new Date(),
      updatedAt: new Date(),
      views: 0
    };

    posts.set(post.id, post);

    eventBus.publish({
      type: 'content.created',
      source: 'blog',
      data: { postId: post.id, title: post.title, author: post.author }
    });

    res.status(201).json(FormatterUtils.createSuccessResponse(post));
  } catch (error) {
    res.status(500).json(FormatterUtils.createErrorResponse((error as Error).message));
  }
});

// Get all blog posts
app.get('/api/v1/blog/posts', (req: Request, res: Response) => {
  try {
    const { status = 'published', category, page = 1, limit = 10 } = req.query;

    let filtered = Array.from(posts.values());

    if (status) {
      filtered = filtered.filter(p => p.status === status);
    }

    if (category) {
      filtered = filtered.filter(p => p.category === category);
    }

    // Sort by published date (newest first)
    filtered.sort((a, b) => (b.publishedAt?.getTime() || 0) - (a.publishedAt?.getTime() || 0));

    const start = (Number(page) - 1) * Number(limit);
    const paginated = filtered.slice(start, start + Number(limit));

    res.json({
      success: true,
      data: paginated,
      total: filtered.length,
      page: Number(page),
      limit: Number(limit),
      totalPages: Math.ceil(filtered.length / Number(limit))
    });
  } catch (error) {
    res.status(500).json(FormatterUtils.createErrorResponse((error as Error).message));
  }
});

// Get single blog post
app.get('/api/v1/blog/posts/:id', (req: Request, res: Response) => {
  try {
    const post = posts.get(req.params.id);

    if (!post) {
      return res.status(404).json({ error: 'Post not found' });
    }

    // Increment views
    post.views++;

    res.json(FormatterUtils.createSuccessResponse(post));
  } catch (error) {
    res.status(500).json(FormatterUtils.createErrorResponse((error as Error).message));
  }
});

// Get by slug
app.get('/api/v1/blog/posts/slug/:slug', (req: Request, res: Response) => {
  try {
    const post = Array.from(posts.values()).find(p => p.slug === req.params.slug);

    if (!post) {
      return res.status(404).json({ error: 'Post not found' });
    }

    post.views++;
    res.json(FormatterUtils.createSuccessResponse(post));
  } catch (error) {
    res.status(500).json(FormatterUtils.createErrorResponse((error as Error).message));
  }
});

// Update blog post
app.put('/api/v1/blog/posts/:id', (req: Request, res: Response) => {
  try {
    const post = posts.get(req.params.id);

    if (!post) {
      return res.status(404).json({ error: 'Post not found' });
    }

    Object.assign(post, { ...req.body, updatedAt: new Date() });

    eventBus.publish({
      type: 'content.updated',
      source: 'blog',
      data: { postId: post.id, title: post.title }
    });

    res.json(FormatterUtils.createSuccessResponse(post));
  } catch (error) {
    res.status(500).json(FormatterUtils.createErrorResponse((error as Error).message));
  }
});

// Publish blog post
app.post('/api/v1/blog/posts/:id/publish', (req: Request, res: Response) => {
  try {
    const post = posts.get(req.params.id);

    if (!post) {
      return res.status(404).json({ error: 'Post not found' });
    }

    post.status = 'published';
    post.publishedAt = new Date();
    post.updatedAt = new Date();

    eventBus.publish({
      type: 'content.published',
      source: 'blog',
      data: { postId: post.id, title: post.title, publishedAt: post.publishedAt }
    });

    res.json(FormatterUtils.createSuccessResponse(post));
  } catch (error) {
    res.status(500).json(FormatterUtils.createErrorResponse((error as Error).message));
  }
});

// Delete blog post
app.delete('/api/v1/blog/posts/:id', (req: Request, res: Response) => {
  try {
    if (!posts.has(req.params.id)) {
      return res.status(404).json({ error: 'Post not found' });
    }

    posts.delete(req.params.id);

    eventBus.publish({
      type: 'content.deleted',
      source: 'blog',
      data: { postId: req.params.id }
    });

    res.json(FormatterUtils.createSuccessResponse({ deleted: true }));
  } catch (error) {
    res.status(500).json(FormatterUtils.createErrorResponse((error as Error).message));
  }
});

// Get blog categories
app.get('/api/v1/blog/categories', (req: Request, res: Response) => {
  const categories = Array.from(new Set(Array.from(posts.values()).map(p => p.category)));
  res.json(FormatterUtils.createSuccessResponse({ categories }));
});

// Get blog tags
app.get('/api/v1/blog/tags', (req: Request, res: Response) => {
  const tags = Array.from(new Set(Array.from(posts.values()).flatMap(p => p.tags)));
  res.json(FormatterUtils.createSuccessResponse({ tags }));
});

// Add comment to post
app.post('/api/v1/blog/posts/:id/comments', (req: Request, res: Response) => {
  try {
    const post = posts.get(req.params.id);

    if (!post) {
      return res.status(404).json({ error: 'Post not found' });
    }

    const { author, email, content } = req.body;

    if (!author || !email || !content) {
      return res.status(400).json({ error: 'Author, email, and content required' });
    }

    const comment: BlogComment = {
      id: uuid(),
      postId: req.params.id,
      author,
      email,
      content,
      approved: false,
      createdAt: new Date()
    };

    comments.set(comment.id, comment);

    eventBus.publish({
      type: 'content.updated',
      source: 'blog',
      data: { postId: req.params.id, event: 'comment-added' }
    });

    res.status(201).json(FormatterUtils.createSuccessResponse(comment));
  } catch (error) {
    res.status(500).json(FormatterUtils.createErrorResponse((error as Error).message));
  }
});

// Get post comments
app.get('/api/v1/blog/posts/:id/comments', (req: Request, res: Response) => {
  try {
    const postComments = Array.from(comments.values())
      .filter(c => c.postId === req.params.id && c.approved);

    res.json(FormatterUtils.createSuccessResponse(postComments));
  } catch (error) {
    res.status(500).json(FormatterUtils.createErrorResponse((error as Error).message));
  }
});

// Search blog posts
app.get('/api/v1/blog/search', (req: Request, res: Response) => {
  try {
    const q = (req.query.q as string)?.toLowerCase() || '';

    if (!q) {
      return res.status(400).json({ error: 'Search query required' });
    }

    const results = Array.from(posts.values())
      .filter(p => p.status === 'published' && (
        p.title.toLowerCase().includes(q) ||
        p.content.toLowerCase().includes(q) ||
        p.tags.some(tag => tag.toLowerCase().includes(q))
      ));

    res.json(FormatterUtils.createSuccessResponse(results));
  } catch (error) {
    res.status(500).json(FormatterUtils.createErrorResponse((error as Error).message));
  }
});

// Error handling
app.use((err: any, req: Request, res: Response, next: NextFunction) => {
  console.error('Blog Service Error:', err);
  res.status(500).json(FormatterUtils.createErrorResponse('Internal Server Error'));
});

app.listen(PORT, () => {
  console.log(`🚀 Blog service running on port ${PORT}`);
  console.log(`📝 API: http://localhost:${PORT}/api/v1/blog`);
});
