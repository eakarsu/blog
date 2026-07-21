require_relative "boot"

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Blog
  class Application < Rails::Application
    config.load_defaults 8.0
    config.time_zone = ENV.fetch("APP_TIME_ZONE", "UTC")
    config.active_record.schema_format = :ruby
    config.autoload_lib(ignore: %w[assets tasks])
    config.action_dispatch.default_headers.merge!(
      "Referrer-Policy" => "strict-origin-when-cross-origin",
      "Permissions-Policy" => "camera=(), microphone=(), geolocation=()",
      "X-Content-Type-Options" => "nosniff",
      "X-Frame-Options" => "DENY"
    )
  end
end
