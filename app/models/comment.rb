class Comment < ActiveRecord::Base
  STATUSES = %w[pending approved rejected].freeze

  belongs_to :article
  belongs_to :moderated_by, class_name: "User", optional: true
  validates :commenter, presence: true, length: { maximum: 80 }
  validates :body, presence: true, length: { minimum: 2, maximum: 2_000 }
  validates :status, inclusion: { in: STATUSES }
  validates :moderation_reason, length: { maximum: 240 }, allow_blank: true

  scope :approved, -> { where(status: "approved").order(created_at: :asc) }
  scope :awaiting_moderation, -> { where(status: "pending").order(created_at: :asc) }

  def moderate!(target, actor:, reason: nil)
    raise SecurityError, "editor role required" unless actor&.editor?
    raise ArgumentError, "invalid moderation state" unless %w[approved rejected].include?(target)
    raise ArgumentError, "rejection reason is required" if target == "rejected" && reason.to_s.strip.empty?

    transaction do
      update!(status: target, moderated_by: actor, moderated_at: Time.current,
              moderation_reason: reason.to_s.strip.presence)
      AuditEvent.record!(actor: actor, action: "comment.#{target}", subject: self,
                         metadata: { article_id: article_id, reason: moderation_reason }.compact)
    end
  end
end
