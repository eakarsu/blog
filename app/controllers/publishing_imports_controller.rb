class PublishingImportsController < ApplicationController
  before_action :require_user

  def create
    return head :forbidden unless current_user.administrator?
    upload = params.require(:archive)
    raise ArgumentError, "archive exceeds 10 MiB" if upload.size > 10.megabytes
    Publishing::Archive.import!(upload.read, actor: current_user)
    redirect_to articles_path, notice: "Archive imported."
  rescue JSON::ParserError, KeyError, TypeError, ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    redirect_to articles_path, alert: "Import rejected: #{error.message}"
  end
end
