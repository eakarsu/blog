class AuditEventsController < ApplicationController
  before_action :require_administrator

  def index
    @audit_events = AuditEvent.includes(:actor).order(created_at: :desc).paginate(page: params[:page], per_page: 50)
  end

  private

  def require_administrator
    head :forbidden unless current_user&.administrator?
  end
end
