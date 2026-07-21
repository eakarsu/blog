require "test_helper"

class PrivacyBoundariesTest < ActionDispatch::IntegrationTest
  setup do
    @author = User.create!(username: "private-author", email: "private-author@example.test", password: "strong password", role: "author")
    @category = Category.create!(name: "Private drafts")
    @draft = @author.articles.create!(title: "Unreleased roadmap", description: "This draft must never appear to public readers.", categories: [@category])
  end

  test "drafts do not leak through author or taxonomy pages" do
    get user_path(@author)
    assert_response :success
    assert_not_includes response.body, @draft.title

    get category_path(@category)
    assert_response :success
    assert_not_includes response.body, @draft.title

    get article_path(@draft)
    assert_response :not_found
  end

  test "user administration is not public" do
    get users_path
    assert_response :forbidden
  end
end
