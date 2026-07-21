class UsersController < ApplicationController
  before_action :set_user, only: %i[edit update show destroy]
  before_action :require_same_user, only: %i[edit update]
  before_action :require_admin, only: %i[index destroy]

  def new
    @user = User.new
  end

  def create
    Publishing::RateLimiter.check!(identity: client_identity, operation: "signup", limit: 5, window: 1.hour)
    @user = User.new(user_params.merge(role: "author", active: true))
    if @user.save
      reset_session
      session[:user_id] = @user.id
      AuditEvent.record!(actor: @user, action: "user.created", subject: @user, request_id: request.request_id)
      redirect_to user_path(@user), notice: "Welcome to Blog, #{@user.username}."
    else
      render :new, status: :unprocessable_entity
    end
  rescue SecurityError => error
    @user ||= User.new(user_params)
    flash.now[:danger] = error.message
    render :new, status: :too_many_requests
  end

  def edit; end

  def show
    source = logged_in? && (current_user == @user || current_user.editor?) ? @user.articles : @user.articles.visible_to_public
    @user_articles = source.newest_first.paginate(page: params[:page], per_page: 20)
  end

  def update
    attributes = user_params
    if current_user.administrator?
      requested_role = params.dig(:user, :role).to_s
      attributes[:role] = requested_role if User::ROLES.include?(requested_role)
      attributes[:active] = ActiveModel::Type::Boolean.new.cast(params.dig(:user, :active)) if params[:user].key?(:active)
    end
    removes_last_admin = @user.administrator? && @user.active? &&
      (attributes[:role].present? && attributes[:role] != "administrator" || attributes[:active] == false) &&
      User.where(role: "administrator", active: true).count == 1
    return redirect_to(edit_user_path(@user), alert: "The last active administrator cannot be demoted or deactivated.") if removes_last_admin
    if @user.update(attributes)
      AuditEvent.record!(actor: current_user, action: "user.updated", subject: @user, request_id: request.request_id)
      redirect_to user_path(@user), notice: "Account updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def index
    @users = User.order(:username).paginate(page: params[:page], per_page: 20)
  end

  def destroy
    if @user == current_user
      return redirect_to users_path, alert: "Administrators cannot deactivate their own active session."
    end
    @user.update!(active: false)
    AuditEvent.record!(actor: current_user, action: "user.deactivated", subject: @user, request_id: request.request_id)
    redirect_to users_path, notice: "User deactivated; authored records were retained."
  end

  private

  def user_params
    params.require(:user).permit(:username, :email, :password)
  end

  def set_user
    @user = User.find(params[:id])
  end

  def require_same_user
    head :forbidden unless logged_in? && (current_user == @user || current_user.administrator?)
  end

  def require_admin
    head :forbidden unless logged_in? && current_user.administrator?
  end
end
