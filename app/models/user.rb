class User < ActiveRecord::Base

  ROLES = %w[author editor administrator].freeze

  validates :username, presence: true,
            uniqueness: { case_sensitive: false },
            length: { minimum: 3, maximum: 25 }

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email, presence: true, length: { maximum: 105 },
            uniqueness: { case_sensitive: false },
            format: { with: VALID_EMAIL_REGEX }

  has_many :articles, dependent: :destroy
  has_many :article_revisions, foreign_key: :editor_id, dependent: :restrict_with_error
  validates :role, inclusion: { in: ROLES }
  validates :password, length: { minimum: 12, maximum: 72 }, if: -> { password.present? }
  before_validation do
    self.email = email.to_s.downcase.strip
    self.username = username.to_s.strip.downcase
  end
  has_secure_password

  def editor?
    role.in?(%w[editor administrator])
  end

  def administrator?
    role == "administrator"
  end

  def admin?
    administrator?
  end

end
