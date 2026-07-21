require "test_helper"

class CommentModerationTest < ActionDispatch::IntegrationTest
  setup do
    @author = User.create!(username: "discussion-author", email: "discussion-author@example.test", password: "strong password", role: "author")
    @editor = User.create!(username: "discussion-editor", email: "discussion-editor@example.test", password: "strong password", role: "editor")
    @article = @author.articles.create!(title: "Public discussion", description: "An article ready for moderated reader discussion.", status: "published", published_at: Time.current)
  end

  test "public submission stays hidden until an editor approves it" do
    post article_comments_path(@article), params: { comment: { commenter: "Reader", body: "Please moderate this first.", website: "" } }
    assert_redirected_to article_path(@article)
    comment = @article.comments.order(:id).last
    assert_equal "pending", comment.status

    get article_path(@article)
    assert_response :success
    assert_not_includes response.body, "Please moderate this first."

    sign_in_as(@editor, "strong password")
    post approve_article_comment_path(@article, comment)
    assert_redirected_to article_path(@article)
    delete logout_path

    get article_path(@article)
    assert_response :success
    assert_includes response.body, "Please moderate this first."
  end

  test "honeypot submission is rejected" do
    assert_no_difference("Comment.count") do
      post article_comments_path(@article), params: { comment: { commenter: "Bot", body: "Spam", website: "https://spam.invalid" } }
    end
    assert_response :unprocessable_entity
  end
end
