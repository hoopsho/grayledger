source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://github.com/hotwired/turbo-rails]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Mission Control for Solid Queue admin UI
gem "mission_control-jobs"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# Money value objects for currency handling [ADR-01.001]
# NOTE: Last release 2021, testing Rails 8 compatibility
gem "money-rails"

# Authorization with policy-based approach [https://github.com/varvet/pundit]
# TASK-2.2: Pundit for authorization policies
gem "pundit", "~> 2.4"

# Pagination - fastest pagination gem [https://github.com/ddnexus/pagy]
# TASK-2.2: Pagy for high-performance pagination
gem "pagy", "~> 9.4"

# Rate limiting and security hardening [https://github.com/rack/rack-attack]
# TASK-4.1: Rack::Attack for DDoS protection and rate limiting
gem "rack-attack", "~> 6.7"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Standard linter for Rails 8 [https://github.com/standardrb/standard]
  # TASK-3.5: Standard linter for code style
  gem "standard", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Email delivery previews for development [https://github.com/fgrehm/letter_opener_web]
  # TASK-3.6: letter_opener_web for email preview UI
  gem "letter_opener_web"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # VCR - Record HTTP interactions for testing [https://github.com/vcr/vcr]
  # TASK-3.2: VCR for HTTP mocking and recording
  gem "vcr", "~> 6.3"

  # WebMock - Mock HTTP requests [https://github.com/bblimke/webmock]
  # TASK-3.2: WebMock for stubbing HTTP requests
  gem "webmock", "~> 3.23"

  # Code coverage tracking [https://github.com/simplecov-ruby/simplecov]
  # TASK-3.3: SimpleCov for test coverage reporting with 90% minimum threshold
  gem "simplecov", "~> 0.22.0", require: false
end
