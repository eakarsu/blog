require "test_helper"

class EditorialJourneyTest < ActionDispatch::IntegrationTest
  setup do
    @author = User.create!(username: "journey-author", email: "journey-author@example.test", password: "strong password", role: "author")
    @editor = User.create!(username: "journey-editor", email: "journey-editor@example.test", password: "strong password", role: "editor")
  end

  test "draft remains private until independent publication" do
    sign_in_as(@author, "strong password")
    post articles_path, params: { article: { title: "From draft to publication", description: "This article follows the complete governed editorial path." } }
    article = Article.order(:id).last
    assert_redirected_to article_path(article)

    post submit_for_review_article_path(article)
    assert_equal "in_review", article.reload.status
    delete logout_path

    sign_in_as(@editor, "strong password")
    post approve_article_path(article)
    post publish_article_path(article)
    assert_equal "published", article.reload.status

    delete logout_path
    get article_path(article)
    assert_response :success
    get articles_path, params: { q: "governed editorial" }
    assert_includes response.body, "From draft to publication"
    get feed_path(format: :atom)
    assert_response :success
    assert_includes response.media_type, "application/atom+xml"
  end
end
