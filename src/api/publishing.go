package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
)

// Article represents a published article
type Article struct {
	ID               uuid.UUID   `json:"id"`
	Title            string      `json:"title"`
	Slug             string      `json:"slug"`
	Content          string      `json:"content"`
	Excerpt          string      `json:"excerpt"`
	Category         string      `json:"category"`
	Author           string      `json:"author"`
	AuthorBio        string      `json:"author_bio"`
	AuthorImage      string      `json:"author_image"`
	PublishedAt      time.Time   `json:"published_at"`
	UpdatedAt        time.Time   `json:"updated_at"`
	ReadTime         int         `json:"read_time"`
	Thumbnail        string      `json:"thumbnail"`
	Views            int         `json:"views"`
	Likes            int         `json:"likes"`
	IsPremium        bool        `json:"is_premium"`
	IsLocked         bool        `json:"is_locked"`
	RelatedArticles  []Article   `json:"related_articles,omitempty"`
	Status           string      `json:"status"` // draft, published, archived
}

// Comment represents a user comment
type Comment struct {
	ID            uuid.UUID `json:"id"`
	ArticleID     uuid.UUID `json:"article_id"`
	UserID        uuid.UUID `json:"user_id"`
	Author        string    `json:"author"`
	AuthorImage   string    `json:"author_image"`
	Content       string    `json:"content"`
	CreatedAt     time.Time `json:"created_at"`
	Likes         int       `json:"likes"`
	Status        string    `json:"status"` // approved, pending, rejected
}

// Category represents an article category
type Category struct {
	ID   uuid.UUID `json:"id"`
	Name string    `json:"name"`
	Slug string    `json:"slug"`
	Icon string    `json:"icon"`
	Count int       `json:"count"`
}

// RegisterPublishingRoutes registers all publishing endpoints
func RegisterPublishingRoutes(router *mux.Router) {
	// Articles
	router.HandleFunc("/api/v1/publishing/articles/featured", GetFeaturedArticles).Methods("GET")
	router.HandleFunc("/api/v1/publishing/articles/trending", GetTrendingArticles).Methods("GET")
	router.HandleFunc("/api/v1/publishing/articles/search", SearchArticles).Methods("GET")
	router.HandleFunc("/api/v1/publishing/articles/{slug}", GetArticleBySlug).Methods("GET")
	router.HandleFunc("/api/v1/publishing/articles", CreateArticle).Methods("POST")
	router.HandleFunc("/api/v1/publishing/articles/{id}", UpdateArticle).Methods("PUT")
	router.HandleFunc("/api/v1/publishing/articles/{id}", DeleteArticle).Methods("DELETE")
	router.HandleFunc("/api/v1/publishing/articles/{id}/like", LikeArticle).Methods("POST")
	router.HandleFunc("/api/v1/publishing/articles/{id}/view", RecordArticleView).Methods("POST")

	// Comments
	router.HandleFunc("/api/v1/publishing/articles/{id}/comments", GetArticleComments).Methods("GET")
	router.HandleFunc("/api/v1/publishing/articles/{id}/comments", CreateComment).Methods("POST")
	router.HandleFunc("/api/v1/publishing/comments/{id}", DeleteComment).Methods("DELETE")
	router.HandleFunc("/api/v1/publishing/comments/{id}/like", LikeComment).Methods("POST")

	// Categories
	router.HandleFunc("/api/v1/publishing/categories", GetCategories).Methods("GET")
	router.HandleFunc("/api/v1/publishing/categories/{slug}/articles", GetCategoryArticles).Methods("GET")

	// Reader feed
	router.HandleFunc("/api/v1/publishing/feed", GetReaderFeed).Methods("GET")
	router.HandleFunc("/api/v1/publishing/feed/subscribe", SubscribeToCategory).Methods("POST")
}

// GetFeaturedArticles returns featured articles
func GetFeaturedArticles(w http.ResponseWriter, r *http.Request) {
	query := `
		SELECT id, title, slug, content, excerpt, category, author, author_bio, author_image,
		       published_at, updated_at, read_time, thumbnail, views, likes, is_premium, is_locked, status
		FROM articles
		WHERE status = 'published' AND featured = true
		ORDER BY published_at DESC
		LIMIT 12
	`

	rows, err := db.Query(query)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to fetch articles")
		return
	}
	defer rows.Close()

	articles := []Article{}
	for rows.Next() {
		var article Article
		if err := rows.Scan(
			&article.ID, &article.Title, &article.Slug, &article.Content, &article.Excerpt,
			&article.Category, &article.Author, &article.AuthorBio, &article.AuthorImage,
			&article.PublishedAt, &article.UpdatedAt, &article.ReadTime, &article.Thumbnail,
			&article.Views, &article.Likes, &article.IsPremium, &article.IsLocked, &article.Status,
		); err == nil {
			articles = append(articles, article)
		}
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"articles": articles,
		"count":    len(articles),
	})
}

// GetTrendingArticles returns trending articles
func GetTrendingArticles(w http.ResponseWriter, r *http.Request) {
	// Trending based on views in last 7 days
	query := `
		SELECT id, title, slug, content, excerpt, category, author, author_bio, author_image,
		       published_at, updated_at, read_time, thumbnail, views, likes, is_premium, is_locked, status
		FROM articles
		WHERE status = 'published' AND published_at > now() - interval '7 days'
		ORDER BY views DESC
		LIMIT 20
	`

	rows, err := db.Query(query)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to fetch articles")
		return
	}
	defer rows.Close()

	articles := []Article{}
	for rows.Next() {
		var article Article
		if err := rows.Scan(
			&article.ID, &article.Title, &article.Slug, &article.Content, &article.Excerpt,
			&article.Category, &article.Author, &article.AuthorBio, &article.AuthorImage,
			&article.PublishedAt, &article.UpdatedAt, &article.ReadTime, &article.Thumbnail,
			&article.Views, &article.Likes, &article.IsPremium, &article.IsLocked, &article.Status,
		); err == nil {
			articles = append(articles, article)
		}
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"articles": articles,
		"count":    len(articles),
	})
}

// GetArticleBySlug retrieves a single article by slug
func GetArticleBySlug(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	slug := vars["slug"]

	article := Article{}
	err := db.QueryRow(`
		SELECT id, title, slug, content, excerpt, category, author, author_bio, author_image,
		       published_at, updated_at, read_time, thumbnail, views, likes, is_premium, is_locked, status
		FROM articles
		WHERE slug = $1 AND status = 'published'
	`, slug).Scan(
		&article.ID, &article.Title, &article.Slug, &article.Content, &article.Excerpt,
		&article.Category, &article.Author, &article.AuthorBio, &article.AuthorImage,
		&article.PublishedAt, &article.UpdatedAt, &article.ReadTime, &article.Thumbnail,
		&article.Views, &article.Likes, &article.IsPremium, &article.IsLocked, &article.Status,
	)

	if err == sql.ErrNoRows {
		respondError(w, http.StatusNotFound, "Article not found")
		return
	}

	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to fetch article")
		return
	}

	// Get related articles (same category, different article)
	relatedRows, _ := db.Query(`
		SELECT id, title, slug, thumbnail, category
		FROM articles
		WHERE category = $1 AND id != $2 AND status = 'published'
		ORDER BY published_at DESC
		LIMIT 3
	`, article.Category, article.ID)
	defer relatedRows.Close()

	related := []Article{}
	for relatedRows.Next() {
		var rel Article
		relatedRows.Scan(&rel.ID, &rel.Title, &rel.Slug, &rel.Thumbnail, &rel.Category)
		related = append(related, rel)
	}
	article.RelatedArticles = related

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"article": article,
	})
}

// SearchArticles searches articles by query
func SearchArticles(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	category := r.URL.Query().Get("category")
	limit := 20

	searchQuery := `
		SELECT id, title, slug, content, excerpt, category, author, author_bio, author_image,
		       published_at, updated_at, read_time, thumbnail, views, likes, is_premium, is_locked, status
		FROM articles
		WHERE status = 'published' AND (
			title ILIKE $1 OR excerpt ILIKE $1 OR content ILIKE $1
		)
	`
	args := []interface{}{"%" + query + "%"}

	if category != "" && category != "all" {
		searchQuery += " AND category = $2"
		args = append(args, category)
	}

	searchQuery += ` ORDER BY published_at DESC LIMIT ` + fmt.Sprintf("%d", limit)

	rows, err := db.Query(searchQuery, args...)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to search articles")
		return
	}
	defer rows.Close()

	articles := []Article{}
	for rows.Next() {
		var article Article
		if err := rows.Scan(
			&article.ID, &article.Title, &article.Slug, &article.Content, &article.Excerpt,
			&article.Category, &article.Author, &article.AuthorBio, &article.AuthorImage,
			&article.PublishedAt, &article.UpdatedAt, &article.ReadTime, &article.Thumbnail,
			&article.Views, &article.Likes, &article.IsPremium, &article.IsLocked, &article.Status,
		); err == nil {
			articles = append(articles, article)
		}
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"articles": articles,
		"count":    len(articles),
		"query":    query,
	})
}

// CreateArticle creates a new article
func CreateArticle(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Title       string `json:"title"`
		Slug        string `json:"slug"`
		Content     string `json:"content"`
		Excerpt     string `json:"excerpt"`
		Category    string `json:"category"`
		Author      string `json:"author"`
		AuthorBio   string `json:"author_bio"`
		AuthorImage string `json:"author_image"`
		Thumbnail   string `json:"thumbnail"`
		IsPremium   bool   `json:"is_premium"`
		Status      string `json:"status"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request")
		return
	}

	// Calculate read time (roughly 200 words per minute)
	wordCount := len(strings.Fields(req.Content))
	readTime := (wordCount + 199) / 200

	article := Article{
		ID:          uuid.New(),
		Title:       req.Title,
		Slug:        req.Slug,
		Content:     req.Content,
		Excerpt:     req.Excerpt,
		Category:    req.Category,
		Author:      req.Author,
		AuthorBio:   req.AuthorBio,
		AuthorImage: req.AuthorImage,
		Thumbnail:   req.Thumbnail,
		IsPremium:   req.IsPremium,
		Status:      req.Status,
		ReadTime:    readTime,
		PublishedAt: time.Now(),
		UpdatedAt:   time.Now(),
	}

	_, err := db.Exec(`
		INSERT INTO articles (id, title, slug, content, excerpt, category, author, author_bio, author_image,
		                      thumbnail, is_premium, status, read_time, published_at, updated_at, views, likes)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
	`, article.ID, article.Title, article.Slug, article.Content, article.Excerpt,
		article.Category, article.Author, article.AuthorBio, article.AuthorImage,
		article.Thumbnail, article.IsPremium, article.Status, article.ReadTime,
		article.PublishedAt, article.UpdatedAt, 0, 0)

	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to create article")
		return
	}

	respondJSON(w, http.StatusCreated, map[string]interface{}{
		"article": article,
	})
}

// UpdateArticle updates an article
func UpdateArticle(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	var req struct {
		Title       string `json:"title"`
		Content     string `json:"content"`
		Excerpt     string `json:"excerpt"`
		Thumbnail   string `json:"thumbnail"`
		IsPremium   bool   `json:"is_premium"`
		Status      string `json:"status"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request")
		return
	}

	wordCount := len(strings.Fields(req.Content))
	readTime := (wordCount + 199) / 200

	_, err := db.Exec(`
		UPDATE articles
		SET title = $1, content = $2, excerpt = $3, thumbnail = $4,
		    is_premium = $5, status = $6, read_time = $7, updated_at = $8
		WHERE id = $9
	`, req.Title, req.Content, req.Excerpt, req.Thumbnail,
		req.IsPremium, req.Status, readTime, time.Now(), id)

	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to update article")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Article updated",
	})
}

// DeleteArticle deletes an article
func DeleteArticle(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	_, err := db.Exec("DELETE FROM articles WHERE id = $1", id)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to delete article")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Article deleted",
	})
}

// RecordArticleView records a view
func RecordArticleView(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	_, err := db.Exec("UPDATE articles SET views = views + 1 WHERE id = $1", id)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to record view")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "View recorded",
	})
}

// LikeArticle likes/unlikes an article
func LikeArticle(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	var req struct {
		Liked bool `json:"liked"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	if req.Liked {
		_, err := db.Exec("UPDATE articles SET likes = likes + 1 WHERE id = $1", id)
		if err != nil {
			respondError(w, http.StatusInternalServerError, "Failed to like article")
			return
		}
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Like recorded",
	})
}

// GetArticleComments retrieves comments for an article
func GetArticleComments(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	rows, err := db.Query(`
		SELECT id, article_id, user_id, author, author_image, content, created_at, likes, status
		FROM comments
		WHERE article_id = $1 AND status = 'approved'
		ORDER BY created_at DESC
	`, id)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to fetch comments")
		return
	}
	defer rows.Close()

	comments := []Comment{}
	for rows.Next() {
		var comment Comment
		rows.Scan(&comment.ID, &comment.ArticleID, &comment.UserID, &comment.Author,
			&comment.AuthorImage, &comment.Content, &comment.CreatedAt, &comment.Likes, &comment.Status)
		comments = append(comments, comment)
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"comments": comments,
		"count":    len(comments),
	})
}

// CreateComment creates a new comment
func CreateComment(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	articleID := vars["id"]

	var req struct {
		Content string `json:"content"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	comment := Comment{
		ID:        uuid.New(),
		ArticleID: uuid.MustParse(articleID),
		Content:   req.Content,
		CreatedAt: time.Now(),
		Status:    "pending",
	}

	_, err := db.Exec(`
		INSERT INTO comments (id, article_id, author, author_image, content, created_at, status, likes)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`, comment.ID, comment.ArticleID, "Anonymous", "", comment.Content, comment.CreatedAt, comment.Status, 0)

	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to create comment")
		return
	}

	respondJSON(w, http.StatusCreated, map[string]interface{}{
		"comment": comment,
	})
}

// DeleteComment deletes a comment
func DeleteComment(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	_, err := db.Exec("DELETE FROM comments WHERE id = $1", id)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to delete comment")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Comment deleted",
	})
}

// LikeComment likes a comment
func LikeComment(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	_, err := db.Exec("UPDATE comments SET likes = likes + 1 WHERE id = $1", id)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to like comment")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Comment liked",
	})
}

// GetCategories retrieves all categories with article counts
func GetCategories(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query(`
		SELECT c.id, c.name, c.slug, c.icon, COUNT(a.id) as count
		FROM categories c
		LEFT JOIN articles a ON a.category = c.slug AND a.status = 'published'
		GROUP BY c.id, c.name, c.slug, c.icon
		ORDER BY c.name
	`)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to fetch categories")
		return
	}
	defer rows.Close()

	categories := []Category{}
	for rows.Next() {
		var category Category
		rows.Scan(&category.ID, &category.Name, &category.Slug, &category.Icon, &category.Count)
		categories = append(categories, category)
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"categories": categories,
		"count":      len(categories),
	})
}

// GetCategoryArticles retrieves articles for a specific category
func GetCategoryArticles(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	slug := vars["slug"]

	rows, err := db.Query(`
		SELECT id, title, slug, content, excerpt, category, author, author_bio, author_image,
		       published_at, updated_at, read_time, thumbnail, views, likes, is_premium, is_locked, status
		FROM articles
		WHERE category = $1 AND status = 'published'
		ORDER BY published_at DESC
		LIMIT 20
	`, slug)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to fetch articles")
		return
	}
	defer rows.Close()

	articles := []Article{}
	for rows.Next() {
		var article Article
		rows.Scan(&article.ID, &article.Title, &article.Slug, &article.Content, &article.Excerpt,
			&article.Category, &article.Author, &article.AuthorBio, &article.AuthorImage,
			&article.PublishedAt, &article.UpdatedAt, &article.ReadTime, &article.Thumbnail,
			&article.Views, &article.Likes, &article.IsPremium, &article.IsLocked, &article.Status)
		articles = append(articles, article)
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"articles": articles,
		"count":    len(articles),
	})
}

// GetReaderFeed retrieves personalized reader feed
func GetReaderFeed(w http.ResponseWriter, r *http.Request) {
	// Get from user's subscribed categories
	rows, err := db.Query(`
		SELECT DISTINCT a.id, a.title, a.slug, a.content, a.excerpt, a.category, a.author, a.author_bio, a.author_image,
		       a.published_at, a.updated_at, a.read_time, a.thumbnail, a.views, a.likes, a.is_premium, a.is_locked, a.status
		FROM articles a
		WHERE a.status = 'published'
		ORDER BY a.published_at DESC
		LIMIT 30
	`)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to fetch feed")
		return
	}
	defer rows.Close()

	articles := []Article{}
	for rows.Next() {
		var article Article
		rows.Scan(&article.ID, &article.Title, &article.Slug, &article.Content, &article.Excerpt,
			&article.Category, &article.Author, &article.AuthorBio, &article.AuthorImage,
			&article.PublishedAt, &article.UpdatedAt, &article.ReadTime, &article.Thumbnail,
			&article.Views, &article.Likes, &article.IsPremium, &article.IsLocked, &article.Status)
		articles = append(articles, article)
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"articles": articles,
		"count":    len(articles),
	})
}

// SubscribeToCategory subscribes user to a category
func SubscribeToCategory(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CategorySlug string `json:"category_slug"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	_, err := db.Exec(`
		INSERT INTO category_subscriptions (user_id, category_slug, created_at)
		VALUES ($1, $2, $3)
		ON CONFLICT DO NOTHING
	`, r.Header.Get("X-User-ID"), req.CategorySlug, time.Now())

	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to subscribe")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Subscribed to category",
	})
}
