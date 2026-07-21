require "digest"
require "json"

module Publishing
  class Archive
    VERSION = 1
    MAX_ARTICLES = 10_000
    MAX_REVISIONS_PER_ARTICLE = 1_000

    def self.export
      {
        format: "blog", version: VERSION, exported_at: Time.current.iso8601,
        users: User.order(:id).map { |user| user.attributes.slice("username", "email", "role", "active") },
        categories: Category.order(:id).pluck(:name),
        tags: Tag.order(:id).pluck(:name),
        articles: Article.includes(:categories, :tags, comments: :moderated_by, article_revisions: :editor).order(:id).map do |article|
          article.attributes.slice("title", "description", "slug", "status", "published_at",
                                   "seo_title", "seo_description", "canonical_url").merge(
            "author_email" => article.user.email,
            "categories" => article.categories.map(&:name),
            "tags" => article.tags.map(&:name),
            "comments" => article.comments.order(:id).map do |comment|
              comment.attributes.slice("commenter", "body", "status", "moderation_reason", "created_at", "updated_at")
                     .merge("moderator_email" => comment.moderated_by&.email)
            end,
            "revisions" => article.article_revisions.order(:number).map do |revision|
              revision.attributes.slice("number", "title", "description", "status", "content_sha256", "created_at", "updated_at")
                      .merge("editor_email" => revision.editor.email)
            end
          )
        end
      }
    end

    def self.import!(payload, actor:)
      raise SecurityError, "administrator role required" unless actor&.administrator?
      data = payload.is_a?(String) ? JSON.parse(payload) : payload
      raise ArgumentError, "unsupported archive" unless data.is_a?(Hash) && data["format"] == "blog" && data["version"] == VERSION
      articles = Array(data["articles"])
      raise ArgumentError, "archive contains too many articles" if articles.length > MAX_ARTICLES
      raise ArgumentError, "archive contains too many users" if Array(data["users"]).length > MAX_ARTICLES

      Article.transaction do
        import_user_identities!(Array(data["users"]))
        articles.each { |row| import_article!(row, actor) }
      end
    end

    def self.import_user_identities!(rows)
      rows.each do |row|
        email = row.fetch("email").to_s.downcase.strip
        next if User.exists?(email: email)
        User.create!(username: unique_username(row.fetch("username")), email: email,
                     password_digest: "!disabled", role: "author", active: false)
      end
    end
    private_class_method :import_user_identities!

    def self.import_article!(row, actor)
      author = User.find_by!(email: row.fetch("author_email").to_s.downcase.strip)
      article = author.articles.find_or_initialize_by(slug: row.fetch("slug"))
      article.assign_attributes(row.slice("title", "description", "status", "published_at",
                                          "seo_title", "seo_description", "canonical_url"))
      article.preserve_imported_slug!(row.fetch("slug"))
      article.save!
      article.categories = Array(row["categories"]).first(100).map { |name| category_for(name) }
      article.tags = Array(row["tags"]).first(100).map { |name| tag_for(name) }
      import_revisions!(article, Array(row["revisions"]))
      import_comments!(article, Array(row["comments"]))
      AuditEvent.record!(actor: actor, action: "article.imported", subject: article)
    end
    private_class_method :import_article!

    def self.import_revisions!(article, rows)
      raise ArgumentError, "article contains too many revisions" if rows.length > MAX_REVISIONS_PER_ARTICLE
      rows.each do |row|
        expected = Digest::SHA256.hexdigest([row.fetch("title"), row.fetch("description"), row.fetch("status")].join("\0"))
        supplied = row.fetch("content_sha256").to_s
        raise ArgumentError, "revision digest mismatch" unless supplied.match?(/\A[0-9a-f]{64}\z/) && ActiveSupport::SecurityUtils.secure_compare(expected, supplied)
        editor = User.find_by!(email: row.fetch("editor_email").to_s.downcase.strip)
        revision = article.article_revisions.find_or_initialize_by(number: Integer(row.fetch("number")))
        next if revision.persisted?
        revision.assign_attributes(editor: editor, title: row.fetch("title"), description: row.fetch("description"),
                                   status: row.fetch("status"), content_sha256: expected,
                                   created_at: row["created_at"], updated_at: row["updated_at"])
        revision.save!
      end
    end
    private_class_method :import_revisions!

    def self.import_comments!(article, rows)
      raise ArgumentError, "article contains too many comments" if rows.length > MAX_REVISIONS_PER_ARTICLE * 10
      rows.each do |row|
        status = row.fetch("status")
        raise ArgumentError, "invalid comment status" unless Comment::STATUSES.include?(status)
        created_at = row["created_at"].presence
        comment = article.comments.find_or_initialize_by(commenter: row.fetch("commenter"), body: row.fetch("body"), created_at: created_at)
        next if comment.persisted?
        moderator = row["moderator_email"].present? ? User.find_by!(email: row["moderator_email"].to_s.downcase.strip) : nil
        comment.assign_attributes(status: status, moderation_reason: row["moderation_reason"], moderated_by: moderator,
                                  moderated_at: moderator ? row["updated_at"] : nil, updated_at: row["updated_at"])
        comment.save!
      end
    end
    private_class_method :import_comments!

    def self.category_for(raw)
      name = raw.to_s.strip.downcase
      Category.find_or_create_by!(name: name)
    end
    private_class_method :category_for

    def self.tag_for(raw)
      name = raw.to_s.strip.downcase
      Tag.find_or_create_by!(name: name)
    end
    private_class_method :tag_for

    def self.unique_username(raw)
      base = raw.to_s.strip.gsub(/[^A-Za-z0-9_-]/, "-").first(20).presence || "imported-user"
      candidate = base
      suffix = 1
      while User.exists?(username: candidate.downcase)
        suffix += 1
        candidate = "#{base.first(20 - suffix.to_s.length - 1)}-#{suffix}"
      end
      candidate
    end
    private_class_method :unique_username
  end
end
