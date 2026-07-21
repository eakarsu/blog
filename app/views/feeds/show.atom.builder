atom_feed do |feed|
  feed.title "Blog"
  feed.updated(@articles.first&.published_at || Time.current)
  @articles.each do |article|
    feed.entry(article, url: article_url(article)) do |entry|
      entry.title(article.title)
      entry.content(article.description, type: "text")
      entry.author { |author| author.name(article.user.username) }
    end
  end
end
