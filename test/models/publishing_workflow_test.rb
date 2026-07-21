require "test_helper"

class PublishingWorkflowTest < ActiveSupport::TestCase
  setup do
    @author = User.create!(username: "author", email: "author@example.test", password: "strong password", role: "author")
    @editor = User.create!(username: "editor", email: "editor@example.test", password: "strong password", role: "editor")
    @other_editor = User.create!(username: "reviewer", email: "reviewer@example.test", password: "strong password", role: "editor")
    @article = @author.articles.create!(title: "A durable publishing workflow", description: "A long enough body for the article model.")
  end

  test "articles start as private drafts with stable slugs" do
    assert_equal "draft", @article.status
    assert_equal "a-durable-publishing-workflow", @article.slug
    assert_not_includes Article.visible_to_public, @article
  end

  test "owner can submit and a different editor can approve and publish" do
    @article.transition_to!("in_review", actor: @author)
    @article.transition_to!("approved", actor: @editor)
    @article.transition_to!("published", actor: @editor)
    assert @article.published_at
    assert_includes Article.visible_to_public, @article
    assert_equal 3, @article.article_revisions.count
    assert_equal 3, AuditEvent.where(subject_type: "Article", subject_id: @article.id).count
  end

  test "author cannot approve own article" do
    @article.transition_to!("in_review", actor: @author)
    assert_raises(SecurityError) { @article.transition_to!("approved", actor: @author) }
    assert_equal "in_review", @article.reload.status
  end

  test "editor cannot publish before approval" do
    @article.transition_to!("in_review", actor: @author)
    assert_raises(ArgumentError) { @article.transition_to!("published", actor: @editor) }
  end

  test "changes requested can be resubmitted" do
    @article.transition_to!("in_review", actor: @author)
    @article.transition_to!("changes_requested", actor: @editor, reason: "Add a source")
    assert_equal "Add a source", @article.moderation_reason
    @article.transition_to!("in_review", actor: @author)
    assert_equal "in_review", @article.status
  end

  test "revision digest is immutable evidence of content" do
    revision = @article.snapshot!(@author)
    assert_match(/\A[0-9a-f]{64}\z/, revision.content_sha256)
    @article.update!(description: "A revised body that is also long enough to pass validation.")
    next_revision = @article.snapshot!(@author)
    assert_not_equal revision.content_sha256, next_revision.content_sha256
  end

  test "tag names normalize to slugs" do
    tag = Tag.create!(name: "Web Accessibility")
    assert_equal "web-accessibility", tag.slug
  end

  test "optimistic locking rejects stale author edits" do
    stale = Article.find(@article.id)
    @article.update!(title: "Fresh title")
    stale.title = "Stale title"
    assert_raises(ActiveRecord::StaleObjectError) { stale.save! }
  end

  test "rate limiter stores only a digest and rejects overflow" do
    2.times { Publishing::RateLimiter.check!(identity: "192.0.2.1", operation: "spec", limit: 2, window: 1.hour) }
    assert_raises(SecurityError) { Publishing::RateLimiter.check!(identity: "192.0.2.1", operation: "spec", limit: 2, window: 1.hour) }
    assert_not_equal "192.0.2.1", RateLimitEvent.last.key_hash
  end

  test "archive rejects unsupported formats without changing records" do
    administrator = User.create!(username: "archive-admin", email: "archive-admin@example.test", password: "strong password", role: "administrator")
    assert_no_difference("Article.count") do
      assert_raises(ArgumentError) { Publishing::Archive.import!({ "format" => "unknown", "version" => 1 }, actor: administrator) }
    end
  end
end
