class ArticleRevision < ActiveRecord::Base
  belongs_to :article
  belongs_to :editor, class_name: "User"
  validates :number, numericality: { only_integer: true, greater_than: 0 }
  validates :content_sha256, format: { with: /\A[0-9a-f]{64}\z/ }

  before_update { throw(:abort) }
  before_destroy { throw(:abort) }
end
