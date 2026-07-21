require "digest"

class CommentsController < ApplicationController
  before_action :set_article
  before_action :set_comment, only: %i[approve reject destroy]
  before_action :require_editor, only: %i[approve reject destroy]

  def create
    return head :not_found unless @article.status == "published" && @article.published_at&.past?
    return head :unprocessable_entity if params.dig(:comment, :website).present?

    Publishing::RateLimiter.check!(identity: client_identity, operation: "comment.create", limit: 5, window: 10.minutes)
    @comment = @article.comments.new(comment_params.merge(
      status: "pending", identity_hash: Digest::SHA256.hexdigest(client_identity)
    ))
    if @comment.save
      AuditEvent.record!(actor: current_user, action: "comment.submitted", subject: @comment,
                         metadata: { article_id: @article.id }, request_id: request.request_id)
      redirect_to article_path(@article), notice: "Comment submitted for moderation."
    else
      redirect_to article_path(@article), alert: @comment.errors.full_messages.to_sentence
    end
  rescue SecurityError => error
    redirect_to article_path(@article), alert: error.message, status: :see_other
  end

  def approve
    @comment.moderate!("approved", actor: current_user)
    redirect_to article_path(@article), notice: "Comment approved."
  end

  def reject
    @comment.moderate!("rejected", actor: current_user, reason: params[:reason])
    redirect_to article_path(@article), notice: "Comment rejected."
  rescue ArgumentError => error
    redirect_to article_path(@article), alert: error.message
  end

  def destroy
    AuditEvent.record!(actor: current_user, action: "comment.deleted", subject: @comment,
                       metadata: { article_id: @article.id }, request_id: request.request_id)
    @comment.destroy!
    redirect_to article_path(@article), notice: "Comment removed."
  end

  private

  def set_article
    @article = Article.locate!(params[:article_id])
  end

  def set_comment
    @comment = @article.comments.find(params[:id])
  end

  def require_editor
    head :forbidden unless current_user&.editor?
  end

  def comment_params
    params.require(:comment).permit(:commenter, :body)
  end
end
