require "test_helper"
require "fileutils"
require "tempfile"
require "tmpdir"

class MediaStoreTest < ActiveSupport::TestCase
  Upload = Struct.new(:path, :content_type, :original_filename) do
    def read(limit)
      File.binread(path, limit)
    end
  end

  setup do
    @author = User.create!(username: "media-author", email: "media-author@example.test", password: "strong password", role: "author")
    @article = @author.articles.create!(title: "Accessible media", description: "An article with validated media content.")
    @root = Dir.mktmpdir("blog-media-test")
    @previous_root = ENV["MEDIA_ROOT"]
    ENV["MEDIA_ROOT"] = @root
  end

  teardown do
    ENV["MEDIA_ROOT"] = @previous_root
    FileUtils.remove_entry(@root) if File.directory?(@root)
  end

  test "stores signature-checked media outside the public tree" do
    file = Tempfile.new(["valid", ".png"])
    file.binmode
    file.write("\x89PNG\r\n\x1A\nverified".b)
    file.close
    asset = Publishing::MediaStore.save!(upload: Upload.new(file.path, "image/png", "safe image.png"), article: @article, actor: @author, alt_text: "Descriptive text")
    assert File.file?(Publishing::MediaStore.path_for!(asset))
    assert_equal "safe_image.png", asset.filename
  ensure
    file&.unlink
  end

  test "rejects a spoofed media type without persistence" do
    file = Tempfile.new(["spoofed", ".png"])
    file.write("not an image")
    file.close
    assert_no_difference("MediaAsset.count") do
      assert_raises(ArgumentError) { Publishing::MediaStore.save!(upload: Upload.new(file.path, "image/png", "bad.png"), article: @article, actor: @author, alt_text: "Bad") }
    end
  ensure
    file&.unlink
  end
end
