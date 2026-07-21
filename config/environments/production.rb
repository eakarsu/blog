Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.active_storage.service = :local
  config.assets.compile = false
  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.new(Logger.new($stdout))
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false
  config.action_controller.default_url_options = {
    host: ENV.fetch("APP_HOST"), protocol: config.force_ssl ? "https" : "http"
  }
  config.hosts << ENV.fetch("APP_HOST")
end
