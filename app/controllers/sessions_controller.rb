class SessionsController < ApplicationController

  skip_before_action :verify_authenticity_token, only: :create, if: -> { request.format.json? }

  def new

  end

  def create
    Publishing::RateLimiter.check!(identity: client_identity, operation: "login", limit: 10, window: 15.minutes)
    credentials = params[:session].presence || params
    user = User.find_by(email: credentials[:email].to_s.downcase, active: true)
    if user && user.authenticate(credentials[:password])
      reset_session
      session[:user_id] = user.id
      user.update_column(:last_signed_in_at, Time.current)
      AuditEvent.record!(actor: user, action: "session.created", subject: user, request_id: request.request_id)
      if request.format.json?
        render json: { success: true, user: session_user(user) }
      else
        flash[:success] = "You have successfully logged in"
        redirect_to user_path(user)
      end
    else
      if request.format.json?
        render json: { error: "Invalid credentials" }, status: :unauthorized
      else
        flash.now[:danger] = "There was something wrong with your login information"
        render :new, status: :unprocessable_entity
      end
    end
  rescue SecurityError => error
    if request.format.json?
      render json: { error: error.message }, status: :too_many_requests
    else
      flash.now[:danger] = error.message
      render :new, status: :too_many_requests
    end
  end

  def show
    if current_user
      render json: { user: session_user(current_user) }
    else
      render json: { error: "Authentication required" }, status: :unauthorized
    end
  end

  def destroy
    AuditEvent.record!(actor: current_user, action: "session.destroyed", subject: current_user, request_id: request.request_id) if current_user
    reset_session
    flash[:success] = "You have logged out"
    redirect_to root_path
  end

  private

  def session_user(user)
    { id: user.id, email: user.email, username: user.username, role: user.role }
  end

end
