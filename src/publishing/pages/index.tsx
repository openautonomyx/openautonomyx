// src/publishing/pages/index.tsx
'use client'

import React, { useState, useEffect } from 'react'
import Link from 'next/link'
import Image from 'next/image'

interface Article {
  id: string
  title: string
  slug: string
  excerpt: string
  category: string
  author: string
  publishedAt: Date
  readTime: number
  thumbnail: string
  featured: boolean
  views: number
  isPremium: boolean
}

interface Category {
  id: string
  name: string
  slug: string
  count: number
  icon: string
}

export default function PublishingHome() {
  const [articles, setArticles] = useState<Article[]>([])
  const [categories, setCategories] = useState<Category[]>([])
  const [selectedCategory, setSelectedCategory] = useState<string>('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    fetchFeaturedArticles()
    fetchCategories()
  }, [])

  const fetchFeaturedArticles = async () => {
    try {
      const response = await fetch('/api/v1/publishing/articles/featured')
      const data = await response.json()
      setArticles(data.articles || [])
    } catch (error) {
      console.error('Failed to fetch articles:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const fetchCategories = async () => {
    try {
      const response = await fetch('/api/v1/publishing/categories')
      const data = await response.json()
      setCategories(data.categories || [])
    } catch (error) {
      console.error('Failed to fetch categories:', error)
    }
  }

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault()
    window.location.href = `/publishing/search?q=${encodeURIComponent(searchQuery)}`
  }

  return (
    <div className="min-h-screen bg-white">
      {/* Navigation */}
      <nav className="border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
          <Link href="/publishing" className="text-2xl font-bold text-blue-600">
            📚 Creative Platform
          </Link>
          <div className="flex gap-6 items-center">
            <Link href="/publishing/browse" className="text-gray-700 hover:text-gray-900">
              Browse
            </Link>
            <Link href="/publishing/trending" className="text-gray-700 hover:text-gray-900">
              Trending
            </Link>
            <Link href="/account" className="text-gray-700 hover:text-gray-900">
              My Account
            </Link>
            <Link href="/account/subscribe" className="bg-blue-600 text-white px-4 py-2 rounded">
              Subscribe
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero Search */}
      <div className="bg-gradient-to-r from-blue-50 to-indigo-50 py-12">
        <div className="max-w-4xl mx-auto px-4">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            Discover Enterprise Insights
          </h1>
          <p className="text-xl text-gray-600 mb-8">
            Research, analysis, and recommendations from industry experts
          </p>

          {/* Search Bar */}
          <form onSubmit={handleSearch} className="flex gap-2">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search articles, topics, authors..."
              className="flex-1 px-4 py-3 rounded-lg border border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <button
              type="submit"
              className="bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 font-medium"
            >
              Search
            </button>
          </form>
        </div>
      </div>

      {/* Featured Article */}
      {articles.length > 0 && (
        <div className="max-w-7xl mx-auto px-4 py-12">
          <div className="bg-gray-50 rounded-lg overflow-hidden">
            <div className="grid grid-cols-3 gap-8 p-8">
              <div className="col-span-2">
                <span className="inline-block bg-blue-100 text-blue-800 px-3 py-1 rounded text-sm font-medium mb-4">
                  {articles[0].category}
                </span>
                <h2 className="text-3xl font-bold text-gray-900 mb-4">
                  {articles[0].title}
                </h2>
                <p className="text-gray-600 text-lg mb-6">
                  {articles[0].excerpt}
                </p>
                <div className="flex items-center gap-4 text-sm text-gray-500">
                  <span>By {articles[0].author}</span>
                  <span>•</span>
                  <span>{articles[0].readTime} min read</span>
                  <span>•</span>
                  <span>{new Date(articles[0].publishedAt).toLocaleDateString()}</span>
                </div>
                <Link
                  href={`/publishing/article/${articles[0].slug}`}
                  className="inline-block mt-6 bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700"
                >
                  Read Full Article →
                </Link>
              </div>
              <div className="col-span-1">
                {articles[0].thumbnail && (
                  <Image
                    src={articles[0].thumbnail}
                    alt={articles[0].title}
                    width={300}
                    height={300}
                    className="rounded-lg object-cover w-full h-64"
                  />
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Category Filter */}
      <div className="max-w-7xl mx-auto px-4 py-8">
        <h3 className="text-lg font-bold text-gray-900 mb-4">Browse by Category</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
          <button
            onClick={() => setSelectedCategory('all')}
            className={`p-4 rounded-lg text-center font-medium transition ${
              selectedCategory === 'all'
                ? 'bg-blue-600 text-white'
                : 'bg-gray-100 text-gray-900 hover:bg-gray-200'
            }`}
          >
            All Articles
          </button>
          {categories.map((category) => (
            <button
              key={category.id}
              onClick={() => setSelectedCategory(category.slug)}
              className={`p-4 rounded-lg text-center font-medium transition ${
                selectedCategory === category.slug
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-900 hover:bg-gray-200'
              }`}
            >
              <div className="text-xl mb-1">{category.icon}</div>
              <div className="text-sm">{category.name}</div>
              <div className="text-xs mt-1">{category.count}</div>
            </button>
          ))}
        </div>
      </div>

      {/* Articles Grid */}
      <div className="max-w-7xl mx-auto px-4 py-12">
        <h3 className="text-2xl font-bold text-gray-900 mb-8">Latest Articles</h3>

        {isLoading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {[...Array(6)].map((_, i) => (
              <div key={i} className="bg-gray-100 rounded-lg h-96 animate-pulse" />
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {articles.map((article) => (
              <article
                key={article.id}
                className="bg-white rounded-lg border border-gray-200 overflow-hidden hover:shadow-lg transition"
              >
                {article.thumbnail && (
                  <Image
                    src={article.thumbnail}
                    alt={article.title}
                    width={400}
                    height={200}
                    className="w-full h-48 object-cover"
                  />
                )}

                <div className="p-6">
                  <div className="flex items-center gap-2 mb-3">
                    <span className="inline-block bg-blue-100 text-blue-800 px-2 py-1 rounded text-xs font-medium">
                      {article.category}
                    </span>
                    {article.isPremium && (
                      <span className="inline-block bg-amber-100 text-amber-800 px-2 py-1 rounded text-xs font-medium">
                        Premium
                      </span>
                    )}
                  </div>

                  <h3 className="text-xl font-bold text-gray-900 mb-2 line-clamp-2">
                    {article.title}
                  </h3>

                  <p className="text-gray-600 text-sm mb-4 line-clamp-2">
                    {article.excerpt}
                  </p>

                  <div className="flex items-center justify-between text-xs text-gray-500 mb-4">
                    <span>{article.readTime} min read</span>
                    <span>{article.views} views</span>
                  </div>

                  <div className="border-t border-gray-200 pt-4 flex items-center justify-between">
                    <span className="text-sm font-medium text-gray-700">
                      {article.author}
                    </span>
                    <Link
                      href={`/publishing/article/${article.slug}`}
                      className="text-blue-600 hover:text-blue-800 font-medium text-sm"
                    >
                      Read →
                    </Link>
                  </div>
                </div>
              </article>
            ))}
          </div>
        )}
      </div>

      {/* CTA Section */}
      <div className="bg-blue-600 text-white py-12 mt-12">
        <div className="max-w-4xl mx-auto px-4 text-center">
          <h2 className="text-3xl font-bold mb-4">Unlock Premium Insights</h2>
          <p className="text-xl mb-8 opacity-90">
            Get exclusive research, deep-dive analysis, and strategic recommendations
          </p>
          <Link
            href="/account/subscribe"
            className="inline-block bg-white text-blue-600 px-8 py-3 rounded-lg font-bold hover:bg-gray-100"
          >
            Subscribe Now
          </Link>
        </div>
      </div>

      {/* Footer */}
      <footer className="bg-gray-900 text-gray-300 py-12">
        <div className="max-w-7xl mx-auto px-4">
          <div className="grid grid-cols-4 gap-8 mb-8">
            <div>
              <h4 className="text-white font-bold mb-4">Company</h4>
              <ul className="space-y-2 text-sm">
                <li><Link href="/about" className="hover:text-white">About</Link></li>
                <li><Link href="/careers" className="hover:text-white">Careers</Link></li>
                <li><Link href="/press" className="hover:text-white">Press</Link></li>
              </ul>
            </div>
            <div>
              <h4 className="text-white font-bold mb-4">Resources</h4>
              <ul className="space-y-2 text-sm">
                <li><Link href="/publishing/browse" className="hover:text-white">Browse Articles</Link></li>
                <li><Link href="/publishing/trending" className="hover:text-white">Trending</Link></li>
                <li><Link href="/publishing/categories" className="hover:text-white">Categories</Link></li>
              </ul>
            </div>
            <div>
              <h4 className="text-white font-bold mb-4">Legal</h4>
              <ul className="space-y-2 text-sm">
                <li><Link href="/privacy" className="hover:text-white">Privacy</Link></li>
                <li><Link href="/terms" className="hover:text-white">Terms</Link></li>
                <li><Link href="/contact" className="hover:text-white">Contact</Link></li>
              </ul>
            </div>
            <div>
              <h4 className="text-white font-bold mb-4">Follow</h4>
              <ul className="space-y-2 text-sm">
                <li><a href="#" className="hover:text-white">Twitter</a></li>
                <li><a href="#" className="hover:text-white">LinkedIn</a></li>
                <li><a href="#" className="hover:text-white">Facebook</a></li>
              </ul>
            </div>
          </div>
          <div className="border-t border-gray-800 pt-8 text-center text-sm">
            <p>&copy; 2026 Creative Platform. All rights reserved.</p>
          </div>
        </div>
      </footer>
    </div>
  )
}
