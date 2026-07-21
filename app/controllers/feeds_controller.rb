class FeedsController < ApplicationController
  def show
    @articles = Article.visible_to_public.newest_first.limit(50)
    response.headers["Cache-Control"] = "public, max-age=300"
  end

  def sitemap
    @articles = Article.visible_to_public.newest_first.limit(10_000)
    response.headers["Cache-Control"] = "public, max-age=3600"
  end
end
