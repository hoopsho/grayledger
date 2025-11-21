# frozen_string_literal: true

# Pagy Initializer for Rails 8
# Fast, powerful pagination gem configuration (Pagy ~> 9.4)
# See https://ddnexus.github.io/pagy/docs/getting-started

# Pagy v9 Configuration
# In Pagy v9+, you can create a custom config that gets merged with DEFAULT
# Using the Pagy::I18n module for internationalization support

# Default items per page (instead of Pagy's default of 20)
# Pagy::DEFAULT[:limit] = 25

# For Rails 8 with Pagy v9.x+:
# Configuration can be passed directly to the pagy() method in controllers:
#   @pagy, @posts = pagy(Post.all, limit: 25, overflow: :last_page)
#
# Or create a helper method for consistency across controllers:
#   def pagy_with_defaults(collection)
#     pagy(collection, limit: 25, overflow: :last_page)
#   end

# Optional: Load Pagy extras as needed (uncomment to enable)
# require "pagy/extras/array"           # To paginate arrays
# require "pagy/extras/calendar"        # Calendar pagination
# require "pagy/extras/elasticsearch_rails" # For Elasticsearch Rails
# require "pagy/extras/headers"         # Send pagination headers
# require "pagy/extras/arel"            # For ARel relations (Rails support)

# Pagy I18n is automatically loaded with English by default
# For other languages, uncomment:
# require "pagy/extras/i18n"
# Pagy::I18n.load(locale: :en)  # Change :en to your locale
