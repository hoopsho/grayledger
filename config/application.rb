require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Grayledger
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # TASK-4.1: Add Rack::Attack middleware for rate limiting
    config.middleware.use Rack::Attack

    # TASK-1.4: Disable schema dumping for non-primary databases
    # We use a single database for all Solid Queue, Cable, and Cache tables,
    # so we only need schema.rb, not separate schema files for cache_schema.rb, etc.
    config.active_record.dump_schemas = :primary
  end
end
