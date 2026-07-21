class CategoriesController < ApplicationController

  before_action :require_admin, except: [:index, :show]

  def index
    @categories = Category.paginate(page: params[:page], per_page: 5)
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)
    if @category.save
      AuditEvent.record!(actor: current_user, action: "category.created", subject: @category, request_id: request.request_id)
      flash[:success] = "Category was created successfully"
      redirect_to categories_path
    else
      render :new, status: :unprocessable_entity
    end
  end


  def show
    @category = Category.find(params[:id])
    source = logged_in? && current_user.editor? ? @category.articles : @category.articles.visible_to_public
    @category_articles = source.newest_first.paginate(page: params[:page], per_page: 20)
  end

  def edit
    @category = Category.find(params[:id])
  end

  def update
    @category = Category.find(params[:id])
    if @category.update(category_params)
      AuditEvent.record!(actor: current_user, action: "category.updated", subject: @category, request_id: request.request_id)
      flash[:success] = "Category name was successfully updated"
      redirect_to category_path(@category)
    else
      render 'edit'
    end
  end

  private

    def category_params
     params.require(:category).permit(:name)
    end

    def require_admin
      unless logged_in? && current_user.administrator?
        flash[:danger] = "Only admins can perform that action"
        redirect_to categories_path
      end
    end

end
