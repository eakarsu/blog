require "test_helper"

class CommentTest < ActiveSupport::TestCase
  setup do
    @author = User.create!(username: "comment-author", email: "comment-author@example.test", password: "strong password", role: "author")
    @editor = User.create!(username: "comment-editor", email: "comment-editor@example.test", password: "strong password", role: "editor")
    @article = @author.articles.create!(title: "Moderated discussion", description: "A published article with governed discussion.", status: "published", published_at: Time.current)
    @comment = @article.comments.create!(commenter: "Reader", body: "A useful contribution.", status: "pending")
  end

  test "pending comments are not publicly approved" do
    assert_not_includes @article.comments.approved, @comment
  end

  test "editor approval is attributable" do
    @comment.moderate!("approved", actor: @editor)
    assert_equal "approved", @comment.status
    assert_equal @editor, @comment.moderated_by
    assert AuditEvent.exists?(action: "comment.approved", subject_id: @comment.id)
  end

  test "rejection requires a reason" do
    assert_raises(ArgumentError) { @comment.moderate!("rejected", actor: @editor) }
    assert_equal "pending", @comment.reload.status
  end

  test "authors cannot moderate comments" do
    assert_raises(SecurityError) { @comment.moderate!("approved", actor: @author) }
  end
end
