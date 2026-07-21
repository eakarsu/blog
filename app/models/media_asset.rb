class MediaAsset < ActiveRecord::Base
  belongs_to :article
  belongs_to :uploaded_by, class_name: "User"
  validates :filename, :content_type, :sha256, :storage_key, :alt_text, presence: true
  validates :byte_size, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 5.megabytes }
  validates :content_type, inclusion: { in: %w[image/jpeg image/png image/webp] }
  validates :alt_text, length: { maximum: 240 }
end
