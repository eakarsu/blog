class Tag < ActiveRecord::Base
  has_many :article_tags, dependent: :destroy
  has_many :articles, through: :article_tags
  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 40 }
  validates :slug, presence: true, uniqueness: true
  before_validation do
    self.name = name.to_s.strip.downcase
    self.slug = name.parameterize
  end
end
