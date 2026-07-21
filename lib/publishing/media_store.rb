require "digest"
require "fileutils"
require "securerandom"

module Publishing
  class MediaStore
    ALLOWED = {
      "image/jpeg" => ["\xFF\xD8\xFF".b],
      "image/png" => ["\x89PNG\r\n\x1A\n".b],
      "image/webp" => ["RIFF".b]
    }.freeze
    MAX_BYTES = 5 * 1024 * 1024

    def self.save!(upload:, article:, actor:, alt_text:)
      bytes = upload.read(MAX_BYTES + 1)
      raise ArgumentError, "file is too large" if bytes.bytesize > MAX_BYTES
      content_type = upload.content_type.to_s
      signatures = ALLOWED.fetch(content_type) { raise ArgumentError, "unsupported media type" }
      valid = signatures.any? { |signature| bytes.start_with?(signature) }
      valid &&= bytes.byteslice(8, 4) == "WEBP" if content_type == "image/webp"
      raise ArgumentError, "file content does not match its media type" unless valid
      raise ArgumentError, "alt text is required" if alt_text.to_s.strip.empty?

      digest = Digest::SHA256.hexdigest(bytes)
      extension = { "image/jpeg" => ".jpg", "image/png" => ".png", "image/webp" => ".webp" }.fetch(content_type)
      key = "#{article.id}/#{SecureRandom.uuid}#{extension}"
      root = Rails.root.join(ENV.fetch("MEDIA_ROOT", "storage/media"))
      path = root.join(key)
      FileUtils.mkdir_p(path.dirname, mode: 0o750)
      temporary = "#{path}.tmp"
      File.binwrite(temporary, bytes, perm: 0o640)
      File.rename(temporary, path)

      MediaAsset.create!(article: article, uploaded_by: actor,
                         filename: File.basename(upload.original_filename.to_s).gsub(/[^A-Za-z0-9._-]/, "_").first(120), content_type: content_type,
                         byte_size: bytes.bytesize, sha256: digest, storage_key: key,
                         alt_text: alt_text.to_s.strip)
    rescue StandardError
      FileUtils.rm_f(temporary) if defined?(temporary) && temporary
      raise
    end

    def self.delete!(asset)
      FileUtils.rm_f(path_for!(asset))
    end

    def self.path_for!(asset)
      raise ArgumentError, "invalid media key" unless asset.storage_key.match?(%r{\A\d+/[0-9a-f-]+\.(?:jpg|png|webp)\z})
      root = Rails.root.join(ENV.fetch("MEDIA_ROOT", "storage/media")).expand_path
      path = root.join(asset.storage_key).cleanpath
      raise ArgumentError, "invalid media key" unless path.to_s.start_with?("#{root}/")
      path
    end
  end
end
