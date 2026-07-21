class CompletePublishingWorkflow < ActiveRecord::Migration[8.0]
  def up
    rename_column :articles, :text, :description
    execute "UPDATE articles SET title = 'Untitled legacy article' WHERE title IS NULL OR title = ''"
    execute "UPDATE articles SET description = 'Legacy article content was empty.' WHERE description IS NULL OR description = ''"
    change_column_null :articles, :title, false
    change_column_null :articles, :description, false

    create_table :users do |t|
      t.string :username, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "author"
      t.boolean :active, null: false, default: true
      t.datetime :last_signed_in_at
      t.timestamps null: false
    end
    add_index :users, :username, unique: true
    add_index :users, :email, unique: true
    execute <<~SQL.squish
      INSERT INTO users (username, email, password_digest, role, active, created_at, updated_at)
      VALUES ('legacy-author', 'legacy-author@invalid.example', '!disabled', 'author', #{connection.quote(false)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL

    add_reference :articles, :user, foreign_key: true
    legacy_user_id = select_value("SELECT id FROM users WHERE email = 'legacy-author@invalid.example'")
    execute "UPDATE articles SET user_id = #{connection.quote(legacy_user_id)} WHERE user_id IS NULL"
    change_column_null :articles, :user_id, false

    create_table :categories do |t|
      t.string :name, null: false
      t.timestamps null: false
    end
    add_index :categories, :name, unique: true
    create_table :article_categories do |t|
      t.references :article, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
    end
    add_index :article_categories, [:article_id, :category_id], unique: true, name: "idx_article_categories_unique"

    add_column :articles, :slug, :string
    add_column :articles, :status, :string, null: false, default: "draft"
    add_column :articles, :published_at, :datetime
    add_column :articles, :moderation_reason, :text
    add_column :articles, :seo_title, :string
    add_column :articles, :seo_description, :string
    add_column :articles, :canonical_url, :string
    add_column :articles, :lock_version, :integer, null: false, default: 0
    ArticleSlugBackfill.new(connection).run
    change_column_null :articles, :slug, false
    add_index :articles, :slug, unique: true
    add_index :articles, [:status, :published_at], name: "idx_articles_status_published"

    create_table :article_revisions do |t|
      t.references :article, null: false, foreign_key: true
      t.references :editor, null: false, foreign_key: { to_table: :users }
      t.integer :number, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.string :status, null: false
      t.string :content_sha256, null: false
      t.timestamps null: false
    end
    add_index :article_revisions, [:article_id, :number], unique: true, name: "idx_article_revisions_unique"

    create_table :tags do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps null: false
    end
    add_index :tags, :name, unique: true
    add_index :tags, :slug, unique: true
    create_table :article_tags do |t|
      t.references :article, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
    end
    add_index :article_tags, [:article_id, :tag_id], unique: true, name: "idx_article_tags_unique"

    create_table :media_assets do |t|
      t.references :article, null: false, foreign_key: true
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.string :filename, null: false
      t.string :content_type, null: false
      t.integer :byte_size, null: false
      t.string :sha256, null: false
      t.string :storage_key, null: false
      t.string :alt_text, null: false
      t.timestamps null: false
    end
    add_index :media_assets, :storage_key, unique: true

    create_table :audit_events do |t|
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :subject_type, null: false
      t.integer :subject_id
      t.json :metadata, null: false, default: {}
      t.string :request_id
      t.timestamps null: false
    end
    add_index :audit_events, [:subject_type, :subject_id, :created_at], name: "idx_audit_subject_time"

    create_table :rate_limit_events do |t|
      t.string :key_hash, null: false
      t.string :operation, null: false
      t.datetime :occurred_at, null: false
    end
    add_index :rate_limit_events, [:key_hash, :operation, :occurred_at], name: "idx_rate_limits"

    execute "UPDATE comments SET commenter = 'Anonymous' WHERE commenter IS NULL OR commenter = ''"
    execute "UPDATE comments SET body = 'Legacy comment content was empty.' WHERE body IS NULL OR body = ''"
    change_column_null :comments, :article_id, false
    change_column_null :comments, :commenter, false
    change_column_null :comments, :body, false
    add_foreign_key :comments, :articles
    add_column :comments, :status, :string, null: false, default: "pending"
    add_reference :comments, :moderated_by, foreign_key: { to_table: :users }
    add_column :comments, :moderated_at, :datetime
    add_column :comments, :moderation_reason, :string
    add_column :comments, :identity_hash, :string
    add_index :comments, [:article_id, :status, :created_at], name: "idx_comments_article_status_time"
  end

  def down
    remove_index :comments, name: "idx_comments_article_status_time"
    remove_column :comments, :identity_hash
    remove_column :comments, :moderation_reason
    remove_column :comments, :moderated_at
    remove_reference :comments, :moderated_by, foreign_key: { to_table: :users }
    remove_column :comments, :status
    remove_foreign_key :comments, :articles
    change_column_null :comments, :body, true
    change_column_null :comments, :commenter, true
    change_column_null :comments, :article_id, true

    drop_table :rate_limit_events
    drop_table :audit_events
    drop_table :media_assets
    drop_table :article_tags
    drop_table :tags
    drop_table :article_revisions
    remove_index :articles, name: "idx_articles_status_published"
    remove_index :articles, name: "index_articles_on_slug"
    remove_columns :articles, :slug, :status, :published_at, :moderation_reason,
                   :seo_title, :seo_description, :canonical_url, :lock_version
    drop_table :article_categories
    drop_table :categories
    remove_reference :articles, :user, foreign_key: true
    drop_table :users
    change_column_null :articles, :description, true
    change_column_null :articles, :title, true
    rename_column :articles, :description, :text
  end

  class ArticleSlugBackfill
    def initialize(connection)
      @connection = connection
    end

    def run
      rows = @connection.select_rows("SELECT id, title FROM articles ORDER BY id")
      used = {}
      rows.each do |id, title|
        base = title.to_s.parameterize.first(140).sub(/-+\z/, "").presence || "article"
        slug = base
        suffix = 1
        while used[slug]
          suffix += 1
          slug = "#{base}-#{suffix}"
        end
        used[slug] = true
        @connection.execute("UPDATE articles SET slug = #{@connection.quote(slug)} WHERE id = #{@connection.quote(id)}")
      end
    end
  end
end
