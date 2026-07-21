require "test_helper"

class ArchiveTest < ActiveSupport::TestCase
  setup do
    @admin = User.create!(username: "archive-admin", email: "archive-admin@example.test", password: "strong password", role: "administrator")
  end

  test "imports portable users, taxonomy, article and verified immutable revision" do
    title = "Portable publishing record"
    description = "A complete portable article body for restore testing."
    status = "published"
    digest = Digest::SHA256.hexdigest([title, description, status].join("\0"))
    payload = {
      "format" => "blog", "version" => 1,
      "users" => [{ "username" => "portable-author", "email" => "portable@example.test" }],
      "articles" => [{
        "title" => title, "description" => description, "slug" => "portable-publishing-record",
        "status" => status, "published_at" => Time.current.iso8601, "author_email" => "portable@example.test",
        "categories" => ["Operations"], "tags" => ["Restore"],
        "revisions" => [{ "number" => 1, "title" => title, "description" => description,
                           "status" => status, "content_sha256" => digest, "editor_email" => "portable@example.test" }]
      }]
    }

    assert_difference(["Article.count", "ArticleRevision.count", "AuditEvent.count"], 1) do
      Publishing::Archive.import!(payload, actor: @admin)
    end
    article = Article.find_by!(slug: "portable-publishing-record")
    assert_equal ["operations"], article.categories.pluck(:name)
    assert_equal ["restore"], article.tags.pluck(:name)
    assert_not article.user.active?
  end

  test "digest mismatch rolls the whole archive back" do
    payload = {
      "format" => "blog", "version" => 1,
      "users" => [{ "username" => "bad-import", "email" => "bad-import@example.test" }],
      "articles" => [{ "title" => "Bad digest", "description" => "This must never persist.", "slug" => "bad-digest",
                       "status" => "draft", "author_email" => "bad-import@example.test", "revisions" => [
                         { "number" => 1, "title" => "Bad digest", "description" => "This must never persist.",
                           "status" => "draft", "content_sha256" => "0" * 64, "editor_email" => "bad-import@example.test" }
                       ] }]
    }
    assert_no_difference(["User.count", "Article.count", "ArticleRevision.count"]) do
      assert_raises(ArgumentError) { Publishing::Archive.import!(payload, actor: @admin) }
    end
  end
end
