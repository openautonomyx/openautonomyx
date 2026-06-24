-- Publishing System Tables

-- Articles table
CREATE TABLE IF NOT EXISTS articles (
  id UUID PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  slug VARCHAR(255) UNIQUE NOT NULL,
  content TEXT NOT NULL,
  excerpt TEXT,
  category VARCHAR(50) NOT NULL,
  author VARCHAR(255) NOT NULL,
  author_bio TEXT,
  author_image VARCHAR(500),
  thumbnail VARCHAR(500),
  published_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  read_time INT DEFAULT 5,
  views INT DEFAULT 0,
  likes INT DEFAULT 0,
  is_premium BOOLEAN DEFAULT false,
  is_locked BOOLEAN DEFAULT false,
  featured BOOLEAN DEFAULT false,
  status VARCHAR(50) DEFAULT 'draft', -- draft, published, archived
  created_by UUID,
  created_at TIMESTAMP DEFAULT NOW(),
  INDEX idx_articles_status (status),
  INDEX idx_articles_category (category),
  INDEX idx_articles_published_at (published_at),
  INDEX idx_articles_slug (slug)
);

-- Categories table
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  slug VARCHAR(100) UNIQUE NOT NULL,
  icon VARCHAR(50),
  description TEXT,
  color VARCHAR(7),
  created_at TIMESTAMP DEFAULT NOW(),
  INDEX idx_categories_slug (slug)
);

-- Comments table
CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY,
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  user_id UUID,
  author VARCHAR(255) NOT NULL,
  author_image VARCHAR(500),
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  likes INT DEFAULT 0,
  status VARCHAR(50) DEFAULT 'pending', -- pending, approved, rejected
  INDEX idx_comments_article_id (article_id),
  INDEX idx_comments_status (status),
  INDEX idx_comments_created_at (created_at)
);

-- Article tags table
CREATE TABLE IF NOT EXISTS article_tags (
  id UUID PRIMARY KEY,
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  tag VARCHAR(50) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  INDEX idx_article_tags_article_id (article_id),
  INDEX idx_article_tags_tag (tag)
);

-- Article likes table
CREATE TABLE IF NOT EXISTS article_likes (
  id UUID PRIMARY KEY,
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(article_id, user_id),
  INDEX idx_article_likes_user_id (user_id),
  INDEX idx_article_likes_article_id (article_id)
);

-- Comment likes table
CREATE TABLE IF NOT EXISTS comment_likes (
  id UUID PRIMARY KEY,
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(comment_id, user_id),
  INDEX idx_comment_likes_user_id (user_id)
);

-- Category subscriptions table
CREATE TABLE IF NOT EXISTS category_subscriptions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  category_slug VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, category_slug),
  INDEX idx_category_subscriptions_user_id (user_id)
);

-- Reading list (bookmarks) table
CREATE TABLE IF NOT EXISTS reading_list (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, article_id),
  INDEX idx_reading_list_user_id (user_id),
  INDEX idx_reading_list_article_id (article_id)
);

-- Article views (analytics) table
CREATE TABLE IF NOT EXISTS article_views (
  id UUID PRIMARY KEY,
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  user_id UUID,
  ip_address VARCHAR(45),
  user_agent TEXT,
  referrer VARCHAR(500),
  time_spent_seconds INT,
  created_at TIMESTAMP DEFAULT NOW(),
  INDEX idx_article_views_article_id (article_id),
  INDEX idx_article_views_created_at (created_at)
);

-- Series/Collections table
CREATE TABLE IF NOT EXISTS article_series (
  id UUID PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  thumbnail VARCHAR(500),
  created_by UUID,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Articles in series table
CREATE TABLE IF NOT EXISTS series_articles (
  id UUID PRIMARY KEY,
  series_id UUID NOT NULL REFERENCES article_series(id) ON DELETE CASCADE,
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  position INT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(series_id, article_id),
  INDEX idx_series_articles_series_id (series_id)
);

-- Insert default categories
INSERT INTO categories (id, name, slug, icon, description) VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 'Technology', 'technology', '🚀', 'Latest tech trends and innovations'),
  ('550e8400-e29b-41d4-a716-446655440001', 'Business', 'business', '💼', 'Business strategy and leadership'),
  ('550e8400-e29b-41d4-a716-446655440002', 'AI & ML', 'ai-ml', '🤖', 'Artificial Intelligence and Machine Learning'),
  ('550e8400-e29b-41d4-a716-446655440003', 'Cloud', 'cloud', '☁️', 'Cloud computing and infrastructure'),
  ('550e8400-e29b-41d4-a716-446655440004', 'Security', 'security', '🔒', 'Cybersecurity and data protection'),
  ('550e8400-e29b-41d4-a716-446655440005', 'Analytics', 'analytics', '📊', 'Data analytics and insights'),
  ('550e8400-e29b-41d4-a716-446655440006', 'Leadership', 'leadership', '👥', 'Executive insights and leadership'),
  ('550e8400-e29b-41d4-a716-446655440007', 'Innovation', 'innovation', '💡', 'Disruptive innovation')
ON CONFLICT DO NOTHING;

-- Row-level security policies for articles
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;

CREATE POLICY article_select_policy ON articles
  FOR SELECT USING (status = 'published' OR (status = 'draft' AND created_by = current_user_id()));

CREATE POLICY article_insert_policy ON articles
  FOR INSERT WITH CHECK (created_by = current_user_id());

CREATE POLICY article_update_policy ON articles
  FOR UPDATE USING (created_by = current_user_id());

-- Full text search index on articles
CREATE INDEX idx_articles_fts ON articles USING GIN(
  to_tsvector('english', title || ' ' || COALESCE(excerpt, '') || ' ' || COALESCE(content, ''))
);
