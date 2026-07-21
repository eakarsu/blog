require "digest"

module Publishing
  class RateLimiter
    def self.check!(identity:, operation:, limit:, window:)
      now = Time.current
      key_hash = Digest::SHA256.hexdigest(identity.to_s)
      RateLimitEvent.where(key_hash: key_hash, operation: operation)
                    .where("occurred_at < ?", now - (window * 2)).delete_all
      current = RateLimitEvent.where(key_hash: key_hash, operation: operation)
                              .where("occurred_at >= ?", now - window).count
      raise SecurityError, "rate limit exceeded" if current >= limit
      RateLimitEvent.create!(key_hash: key_hash, operation: operation, occurred_at: now)
    end
  end
end
