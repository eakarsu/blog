require "digest"
require "uri"

class Article < ActiveRecord::Base
  STATUSES = %w[draft in_review changes_requested approved published archived].freeze

  belongs_to :user
  has_many :article_categories, dependent: :destroy
  has_many :categories, through: :article_categories
  has_many :article_tags, dependent: :destroy
  has_many :tags, through: :article_tags
  has_many :article_revisions, dependent: :restrict_with_error
  has_many :media_assets, dependent: :destroy
  has_many :comments, dependent: :destroy

  validates :title, presence: true, length: { minimum: 3, maximum: 120 }
  validates :description, presence: true, length: { minimum: 10, maximum: 100_000 }
  validates :status, inclusion: { in: STATUSES }
  validates :slug, presence: true, uniqueness: true
  validates :slug, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }, length: { maximum: 160 }
  validates :seo_title, length: { maximum: 70 }, allow_blank: true
  validates :seo_description, length: { maximum: 160 }, allow_blank: true
  validate :canonical_url_is_http
  validate :published_articles_have_a_timestamp

  before_validation :assign_slug
  before_validation :normalize_text_fields

  scope :visible_to_public, -> { where(status: "published").where("published_at <= ?", Time.current) }
  scope :newest_first, -> { order(published_at: :desc, created_at: :desc) }

  def self.locate!(value)
    find_by(slug: value.to_s) || find(value)
  end

  def to_param
    slug.presence || super
  end

  def publicly_visible?
    status == "published" && published_at.present? && published_at <= Time.current
  end

  def transition_to!(target, actor:, reason: nil)
    raise ArgumentError, "a change-request reason is required" if target == "changes_requested" && reason.to_s.strip.empty?
    Publishing::Policy.authorize_transition!(article: self, actor: actor, target: target)
    transaction do
      snapshot!(actor)
      update!(status: target, moderation_reason: reason,
              published_at: target == "published" ? Time.current : published_at)
      AuditEvent.record!(actor: actor, action: "article.#{target}", subject: self,
                         metadata: { from: status_before_last_save, reason: reason }.compact)
    end
  end

  def preserve_imported_slug!(value)
    self.slug = value.to_s
    @preserve_imported_slug = true
  end

  def snapshot!(editor)
    article_revisions.create!(
      editor: editor,
      number: (article_revisions.maximum(:number) || 0) + 1,
      title: title,
      description: description,
      status: status,
      content_sha256: Digest::SHA256.hexdigest([title, description, status].join("\0"))
    )
  end

  private

  def assign_slug
    return if @preserve_imported_slug && slug.present?
    base = title.to_s.parameterize.first(140).sub(/-+\z/, "").presence || "article"
    candidate = base
    suffix = 1
    while self.class.where.not(id: id).exists?(slug: candidate)
      suffix += 1
      candidate = "#{base}-#{suffix}"
    end
    self.slug = candidate if slug.blank? || will_save_change_to_title?
  end

  def normalize_text_fields
    self.title = title.to_s.strip
    self.seo_title = seo_title.to_s.strip.presence
    self.seo_description = seo_description.to_s.strip.presence
    self.canonical_url = canonical_url.to_s.strip.presence
  end

  def canonical_url_is_http
    return if canonical_url.blank?
    uri = URI.parse(canonical_url)
    errors.add(:canonical_url, "must be an absolute HTTP(S) URL") unless uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    errors.add(:canonical_url, "must be an absolute HTTP(S) URL")
  end

  def published_articles_have_a_timestamp
    errors.add(:published_at, "is required") if status == "published" && published_at.blank?
  end
end
