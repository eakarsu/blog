xml.instruct!
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  xml.url do
    xml.loc articles_url
    xml.lastmod(@articles.first&.updated_at&.iso8601 || Time.current.iso8601)
  end
  @articles.each do |article|
    xml.url do
      xml.loc article_url(article)
      xml.lastmod article.updated_at.iso8601
    end
  end
end
