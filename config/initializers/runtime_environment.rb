require "uri"

if Rails.env.production?
  secret = ENV.fetch("SECRET_KEY_BASE")
  if secret.bytesize < 64 || secret.match?(/change|example|dummy|secret-key/i)
    raise "SECRET_KEY_BASE must be a non-placeholder value of at least 64 bytes"
  end

  database = URI.parse(ENV.fetch("DATABASE_URL"))
  raise "DATABASE_URL must use PostgreSQL in production" unless %w[postgres postgresql].include?(database.scheme)

  host = ENV.fetch("APP_HOST")
  raise "APP_HOST must be a hostname without a URL path" unless host.match?(/\A[a-z0-9.-]+(?::\d+)?\z/i)
end
