// src/publishing/pages/article/[slug].tsx
'use client'

import React, { useEffect, useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { useParams } from 'next/navigation'

interface Article {
  id: string
  title: string
  slug: string
  content: string
  excerpt: string
  category: string
  author: string
  authorBio: string
  authorImage: string
  publishedAt: Date
  updatedAt: Date
  readTime: number
  thumbnail: string
  views: number
  likes: number
  isPremium: boolean
  isLocked: boolean
  relatedArticles: Array<{
    id: string
    title: string
    slug: string
    thumbnail: string
    category: string
  }>
}

interface Comment {
  id: string
  author: string
  authorImage: string
  content: string
  createdAt: Date
  likes: number
}

export default function ArticleReader() {
  const params = useParams()
  const slug = params?.slug as string
  const [article, setArticle] = useState<Article | null>(null)
  const [comments, setComments] = useState<Comment[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [liked, setLiked] = useState(false)
  const [commentText, setCommentText] = useState('')
  const [showPaywall, setShowPaywall] = useState(false)

  useEffect(() => {
    if (slug) {
      fetchArticle()
    }
  }, [slug])

  const fetchArticle = async () => {
    try {
      const response = await fetch(`/api/v1/publishing/articles/${slug}`)
      const data = await response.json()
      setArticle(data.article)

      if (data.article.isPremium && data.article.isLocked) {
        setShowPaywall(true)
      }

      fetchComments(data.article.id)
    } catch (error) {
      console.error('Failed to fetch article:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const fetchComments = async (articleId: string) => {
    try {
      const response = await fetch(`/api/v1/publishing/articles/${articleId}/comments`)
      const data = await response.json()
      setComments(data.comments || [])
    } catch (error) {
      console.error('Failed to fetch comments:', error)
    }
  }

  const handleLike = async () => {
    if (!article) return
    setLiked(!liked)
    try {
      await fetch(`/api/v1/publishing/articles/${article.id}/like`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ liked: !liked })
      })
    } catch (error) {
      console.error('Failed to like article:', error)
    }
  }

  const handleComment = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!article || !commentText.trim()) return

    try {
      await fetch(`/api/v1/publishing/articles/${article.id}/comments`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content: commentText })
      })
      setCommentText('')
      fetchComments(article.id)
    } catch (error) {
      console.error('Failed to post comment:', error)
    }
  }

  if (isLoading) {
    return (
      <div className="min-h-screen bg-white">
        <div className="max-w-4xl mx-auto px-4 py-12">
          <div className="animate-pulse space-y-4">
            <div className="h-8 bg-gray-200 rounded w-3/4" />
            <div className="h-96 bg-gray-200 rounded" />
            <div className="space-y-2">
              <div className="h-4 bg-gray-200 rounded" />
              <div className="h-4 bg-gray-200 rounded w-5/6" />
            </div>
          </div>
        </div>
      </div>
    )
  }

  if (!article) {
    return (
      <div className="min-h-screen bg-white flex items-center justify-center">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-4">Article Not Found</h1>
          <Link href="/publishing" className="text-blue-600 hover:text-blue-800">
            ← Back to Home
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-white">
      {/* Navigation */}
      <nav className="border-b border-gray-200">
        <div className="max-w-4xl mx-auto px-4 py-4">
          <Link href="/publishing" className="text-blue-600 hover:text-blue-800 font-medium">
            ← Back to Publishing
          </Link>
        </div>
      </nav>

      {/* Article Container */}
      <div className="max-w-4xl mx-auto px-4 py-12">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center gap-3 mb-4">
            <span className="inline-block bg-blue-100 text-blue-800 px-3 py-1 rounded text-sm font-medium">
              {article.category}
            </span>
            {article.isPremium && (
              <span className="inline-block bg-amber-100 text-amber-800 px-3 py-1 rounded text-sm font-medium">
                🔒 Premium
              </span>
            )}
          </div>

          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            {article.title}
          </h1>

          <p className="text-xl text-gray-600 mb-6">
            {article.excerpt}
          </p>

          <div className="flex items-center justify-between pb-6 border-b border-gray-200">
            <div className="flex items-center gap-4">
              <Image
                src={article.authorImage}
                alt={article.author}
                width={48}
                height={48}
                className="rounded-full"
              />
              <div>
                <div className="font-bold text-gray-900">{article.author}</div>
                <div className="text-sm text-gray-500">
                  {new Date(article.publishedAt).toLocaleDateString()} • {article.readTime} min read
                </div>
              </div>
            </div>

            <div className="flex items-center gap-4">
              <button
                onClick={handleLike}
                className={`flex items-center gap-2 px-4 py-2 rounded-lg transition ${
                  liked
                    ? 'bg-red-100 text-red-600'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                <span className="text-lg">{liked ? '❤️' : '🤍'}</span>
                {article.likes}
              </button>

              <button className="flex items-center gap-2 px-4 py-2 rounded-lg bg-gray-100 text-gray-700 hover:bg-gray-200">
                <span>📤</span>
                Share
              </button>
            </div>
          </div>
        </div>

        {/* Featured Image */}
        {article.thumbnail && (
          <div className="mb-12">
            <Image
              src={article.thumbnail}
              alt={article.title}
              width={800}
              height={400}
              className="w-full rounded-lg object-cover"
            />
          </div>
        )}

        {/* Paywall */}
        {showPaywall && (
          <div className="bg-blue-50 border-2 border-blue-200 rounded-lg p-8 mb-12 text-center">
            <h3 className="text-2xl font-bold text-gray-900 mb-4">📖 This is Premium Content</h3>
            <p className="text-gray-600 mb-6">
              Upgrade your subscription to read full articles and unlock exclusive insights
            </p>
            <Link
              href="/account/subscribe"
              className="inline-block bg-blue-600 text-white px-8 py-3 rounded-lg font-bold hover:bg-blue-700"
            >
              Upgrade to Premium
            </Link>
          </div>
        )}

        {/* Content */}
        {!showPaywall && (
          <article className="prose prose-lg max-w-none mb-12">
            <div
              className="text-gray-700 leading-relaxed"
              dangerouslySetInnerHTML={{ __html: article.content }}
            />
          </article>
        )}

        {/* Author Bio */}
        <div className="bg-gray-50 rounded-lg p-6 mb-12 border border-gray-200">
          <h3 className="text-lg font-bold text-gray-900 mb-4">About the Author</h3>
          <div className="flex gap-4">
            <Image
              src={article.authorImage}
              alt={article.author}
              width={80}
              height={80}
              className="rounded-full flex-shrink-0"
            />
            <div>
              <h4 className="font-bold text-gray-900 mb-2">{article.author}</h4>
              <p className="text-gray-600">{article.authorBio}</p>
            </div>
          </div>
        </div>

        {/* Comments Section */}
        {!showPaywall && (
          <div className="mb-12">
            <h3 className="text-2xl font-bold text-gray-900 mb-6">Comments ({comments.length})</h3>

            {/* Comment Form */}
            <form onSubmit={handleComment} className="mb-8 bg-gray-50 rounded-lg p-6">
              <h4 className="font-bold text-gray-900 mb-4">Leave a Comment</h4>
              <textarea
                value={commentText}
                onChange={(e) => setCommentText(e.target.value)}
                placeholder="Share your thoughts..."
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 mb-4"
                rows={4}
              />
              <button
                type="submit"
                disabled={!commentText.trim()}
                className="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Post Comment
              </button>
            </form>

            {/* Comments List */}
            <div className="space-y-6">
              {comments.map((comment) => (
                <div key={comment.id} className="border-b border-gray-200 pb-6">
                  <div className="flex gap-4">
                    <Image
                      src={comment.authorImage}
                      alt={comment.author}
                      width={40}
                      height={40}
                      className="rounded-full flex-shrink-0"
                    />
                    <div className="flex-1">
                      <div className="font-bold text-gray-900">{comment.author}</div>
                      <div className="text-sm text-gray-500 mb-2">
                        {new Date(comment.createdAt).toLocaleDateString()}
                      </div>
                      <p className="text-gray-700 mb-3">{comment.content}</p>
                      <button className="text-sm text-gray-500 hover:text-gray-700 font-medium">
                        👍 {comment.likes}
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Related Articles */}
        {article.relatedArticles.length > 0 && (
          <div className="mb-12">
            <h3 className="text-2xl font-bold text-gray-900 mb-6">Related Articles</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {article.relatedArticles.map((related) => (
                <Link
                  key={related.id}
                  href={`/publishing/article/${related.slug}`}
                  className="bg-white rounded-lg border border-gray-200 overflow-hidden hover:shadow-lg transition"
                >
                  <Image
                    src={related.thumbnail}
                    alt={related.title}
                    width={300}
                    height={150}
                    className="w-full h-32 object-cover"
                  />
                  <div className="p-4">
                    <span className="text-xs font-medium text-blue-600">
                      {related.category}
                    </span>
                    <h4 className="font-bold text-gray-900 mt-2 line-clamp-2">
                      {related.title}
                    </h4>
                  </div>
                </Link>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Footer */}
      <footer className="bg-gray-900 text-gray-300 py-12 mt-12">
        <div className="max-w-7xl mx-auto px-4 text-center">
          <p>&copy; 2026 Creative Platform. All rights reserved.</p>
        </div>
      </footer>
    </div>
  )
}
