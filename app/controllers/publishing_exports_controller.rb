class PublishingExportsController < ApplicationController
  before_action :require_user

  def show
    return head :forbidden unless current_user.administrator?
    AuditEvent.record!(actor: current_user, action: "archive.exported", subject: current_user, request_id: request.request_id)
    send_data JSON.pretty_generate(Publishing::Archive.export), type: "application/json",
              disposition: "attachment", filename: "blog-#{Date.current.iso8601}.json"
  end
end
