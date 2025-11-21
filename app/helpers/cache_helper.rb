module CacheHelper
  # Generate a cache key for a single record using Russian doll pattern
  #
  # Russian doll caching uses nested fragment caches where parent/child relationships
  # are automatically invalidated via touch: true on associations. This method generates
  # cache keys that include the record's cache_key_with_version for automatic invalidation.
  #
  # @param record [ActiveRecord::Base] the record to cache
  # @param suffixes [Array<String>] additional cache key components (e.g., "profile", "summary")
  # @return [String] cache key with record version
  #
  # @example Basic single record
  #   <% cache nested_cache_key(@user) do %>
  #     <%= render @user %>
  #   <% end %>
  #
  # @example Record with suffix for variant views
  #   <% cache nested_cache_key(@user, "sidebar") do %>
  #     <%= render "sidebar", user: @user %>
  #   <% end %>
  #
  # @example Multiple suffixes for complex keys
  #   <% cache nested_cache_key(@invoice, "summary", "taxes") do %>
  #     <%= render "summary", invoice: @invoice %>
  #   <% end %>
  def nested_cache_key(record, *suffixes)
    [
      record.cache_key_with_version,
      *suffixes
    ].compact.join("/")
  end

  # Generate a cache key for a collection using Russian doll pattern
  #
  # Collections require special handling - we can't rely on individual record
  # timestamps since changing the collection size/order doesn't update individual records.
  # This method creates a cache key from the collection's metadata.
  #
  # @param collection [ActiveRecord::Relation, Array] the collection to cache
  # @param prefix [String] a prefix for the cache key (e.g., "invoices", "transactions")
  # @return [String] cache key representing the collection state
  #
  # @example Collections with ActiveRecord Relation
  #   <% cache collection_cache_key(@user.invoices, "list") do %>
  #     <div class="invoices">
  #       <%= render @user.invoices %>
  #     </div>
  #   <% end %>
  #
  # @example Collections with arrays
  #   <% cache collection_cache_key(active_users, "dashboard") do %>
  #     <%= render active_users %>
  #   <% end %>
  #
  # @note For ActiveRecord::Relation, includes count and max updated_at timestamp.
  #       For arrays, includes length and hash of last element's updated_at.
  def collection_cache_key(collection, prefix)
    if collection.is_a?(ActiveRecord::Relation)
      # For ActiveRecord relations, use count and max timestamp
      # Ensures cache busts when records added/removed/modified
      count = collection.count
      max_timestamp = collection.maximum(:updated_at)&.to_i || 0

      "#{prefix}/collection/#{count}/#{max_timestamp}"
    else
      # For arrays, use length and hash
      count = collection.length
      max_timestamp = collection.map { |r| r&.updated_at&.to_i || 0 }.max || 0

      "#{prefix}/collection/#{count}/#{max_timestamp}"
    end
  end

  # Generate a cache key for a complex object that spans multiple records
  #
  # Use this for views that combine data from multiple models (e.g., a dashboard
  # that shows user profile + recent invoices + stats). Automatically invalidates
  # when any of the dependent records are touched.
  #
  # @param identifier [String] unique identifier for this view component
  # @param dependencies [Array<ActiveRecord::Base>] records that invalidate this cache
  # @return [String] cache key combining identifier with dependency versions
  #
  # @example Dashboard combining user, invoices, and accounts
  #   <% cache composite_cache_key("user_dashboard_#{@user.id}", [@user, @user.invoices]) do %>
  #     <%= render "dashboard", user: @user, invoices: @user.invoices %>
  #   <% end %>
  def composite_cache_key(identifier, *dependencies)
    versions = dependencies.flatten.map do |dep|
      if dep.is_a?(ActiveRecord::Relation)
        collection_cache_key(dep, "collection")
      else
        dep.cache_key_with_version if dep.respond_to?(:cache_key_with_version)
      end
    end.compact

    [identifier, *versions].join("/")
  end

  # Helper to conditionally cache content only in production
  #
  # In development, you often want to see changes immediately without clearing caches.
  # This method enables/disables caching based on environment.
  #
  # @param record [ActiveRecord::Base] the record to cache
  # @param suffixes [Array<String>] additional cache key components
  # @param block [Proc] the content to cache
  #
  # @example Conditionally cache only in production
  #   <% conditional_cache(nested_cache_key(@user)) do %>
  #     <%= expensive_calculation %>
  #   <% end %>
  def conditional_cache(cache_key, &block)
    if Rails.env.production?
      cache(cache_key, &block)
    else
      block.call
    end
  end
end
