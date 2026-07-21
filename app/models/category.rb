class Category < ActiveRecord::Base

  validates :name, presence: true, length: { minimum: 3, maximum: 25 }
  validates :name, uniqueness: { case_sensitive: false }
  before_validation { self.name = name.to_s.strip.downcase }

  has_many :article_categories, dependent: :destroy
  has_many :articles, through: :article_categories

end
