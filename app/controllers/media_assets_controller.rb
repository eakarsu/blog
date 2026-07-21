class MediaAssetsController < ApplicationController
  before_action :require_user, only: %i[create destroy]
  before_action :set_article
  before_action :set_asset, only: %i[show destroy]

  def show
    allowed = @article.publicly_visible? || (logged_in? && (current_user == @article.user || current_user.editor?))
    return head :not_found unless allowed
    path = Publishing::MediaStore.path_for!(@asset)
    return head :not_found unless File.file?(path)
    response.headers["Cache-Control"] = @article.publicly_visible? ? "public, max-age=3600" : "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_file path, type: @asset.content_type, disposition: "inline", filename: @asset.filename
  rescue ArgumentError
    head :not_found
  end

  def create
    return head :forbidden unless current_user == @article.user || current_user.administrator?
    return head :conflict unless %w[draft changes_requested].include?(@article.status)
    Publishing::RateLimiter.check!(identity: current_user.id, operation: "media.create", limit: 20, window: 1.hour)
    asset = Publishing::MediaStore.save!(upload: params.require(:file), article: @article,
                                         actor: current_user, alt_text: params.require(:alt_text))
    AuditEvent.record!(actor: current_user, action: "media.created", subject: asset, request_id: request.request_id)
    redirect_to article_path(@article), notice: "Media uploaded."
  rescue ArgumentError => error
    redirect_to article_path(@article), alert: error.message
  rescue SecurityError => error
    redirect_to article_path(@article), alert: error.message, status: :see_other
  end

  def destroy
    return head :forbidden unless current_user == @article.user || current_user.administrator?
    Publishing::MediaStore.delete!(@asset)
    @asset.destroy!
    AuditEvent.record!(actor: current_user, action: "media.deleted", subject: @asset, request_id: request.request_id)
    redirect_to article_path(@article), notice: "Media removed."
  end

  private

  def set_article
    @article = Article.locate!(params[:article_id])
  end

  def set_asset
    @asset = @article.media_assets.find(params[:id])
  end
end
