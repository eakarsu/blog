module Publishing
  class Policy
    TRANSITIONS = {
      "draft" => %w[in_review archived],
      "changes_requested" => %w[in_review archived],
      "in_review" => %w[changes_requested approved],
      "approved" => %w[published changes_requested],
      "published" => %w[archived],
      "archived" => %w[draft]
    }.freeze

    def self.authorize_transition!(article:, actor:, target:)
      raise ArgumentError, "unknown state" unless TRANSITIONS.key?(article.status) && TRANSITIONS.values.flatten.include?(target)
      raise ArgumentError, "invalid transition" unless TRANSITIONS.fetch(article.status).include?(target)

      owns_article = article.user_id == actor.id
      author_targets = %w[in_review archived draft]
      if author_targets.include?(target)
        raise SecurityError, "not permitted" unless owns_article || actor.editor?
      else
        raise SecurityError, "editor role required" unless actor.editor?
        raise SecurityError, "authors cannot moderate their own work" if owns_article
      end
      true
    end
  end
end
