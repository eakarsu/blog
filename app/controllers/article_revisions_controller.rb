class ArticleRevisionsController < ApplicationController
  before_action :require_user

  def index
    article = Article.locate!(params[:article_id])
    return head :forbidden unless current_user == article.user || current_user.editor?
    render json: article.article_revisions.order(number: :desc).as_json(except: %i[description editor_id], methods: [])
  end

  def show
    article = Article.locate!(params[:article_id])
    return head :forbidden unless current_user == article.user || current_user.editor?
    render json: article.article_revisions.find(params[:id])
  end
end
