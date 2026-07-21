require 'test_helper'

class CreateCategoriesTest < ActionDispatch::IntegrationTest

  def setup
    @user = User.create!(username: "john", email: "john@example.com", password: "strong password", role: "administrator")
  end

  test "get new category form and create category" do
    sign_in_as(@user, "strong password")
    get new_category_path
    assert_response :success
    assert_difference 'Category.count', 1 do
      post categories_path, params: { category: { name: "sports" } }
      follow_redirect!
    end
    assert_response :success
    assert_match "sports", response.body
  end

  test "invalid category submission results in failure" do
    sign_in_as(@user, "strong password")
    get new_category_path
    assert_response :success
    assert_no_difference 'Category.count' do
      post categories_path, params: { category: { name: " " } }
    end
    assert_response :unprocessable_entity
    assert_select 'h2.panel-title'
    assert_select 'div.panel-body'
  end

end
