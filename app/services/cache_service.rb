# CacheService provides high-performance caching utilities with configurable TTLs
# and nested cache key generation for complex objects.
#
# Usage:
#   # Simple cache fetch
#   CacheService.fetch_cached("user_profile:#{user.id}", expires_in: 1.hour) do
#     expensive_calculation
#   end
#
#   # Nested cache key for complex objects
#   CacheService.fetch_cached(
#     CacheService.nested_key("ledger", ["entries", company.id, date]),
#     expires_in: 4.hours
#   ) { LedgerCalculator.balance(company, date) }
#
class CacheService
  # Default cache store (uses Rails.cache)
  def self.cache_store
    Rails.cache
  end

  # Fetch with caching - returns cached value or executes block
  # @param key [String] - cache key
  # @param expires_in [ActiveSupport::Duration] - TTL (default: 1 hour)
  # @param force_miss [Boolean] - skip cache and force recomputation (default: false)
  # @param block [Proc] - block to execute if cache miss
  # @return [Object] - cached or freshly computed value
  def self.fetch_cached(key, expires_in: 1.hour, force_miss: false, &block)
    # Try to read from cache first [TASK-6.2 - Track cache hits/misses]
    value = cache_store.read(key) unless force_miss

    if value.present?
      # Cache hit
      MetricsTracker.track_counter("cache_hits", 1)
      return value
    end

    # Cache miss - compute and store
    MetricsTracker.track_counter("cache_misses", 1)

    if force_miss
      cache_store.delete(key)
    end

    cache_store.fetch(key, expires_in: expires_in, &block)
  end

  # Generate nested cache key from segments
  # @param namespace [String] - top-level namespace
  # @param segments [Array] - variable segments
  # @return [String] - formatted cache key
  #
  # Example:
  #   CacheService.nested_key("user", ["posts", user.id, "trending"])
  #   # => "user:posts:123:trending"
  def self.nested_key(namespace, segments = [])
    parts = [namespace, *segments].compact.map(&:to_s)
    parts.join(":")
  end

  # Delete cache entries matching a pattern
  # @param pattern [String] - pattern to match (e.g., "user:*")
  # @return [Integer] - number of keys deleted
  #
  # Note: Only works with cache stores that support pattern deletion (e.g., Redis).
  # Falls back to no-op for Solid Cache and in-memory stores.
  def self.delete_pattern(pattern)
    if cache_store.respond_to?(:delete_matched)
      cache_store.delete_matched(pattern)
    else
      # Solid Cache and in-memory stores don't support pattern deletion
      # Return 0 to indicate no keys were deleted
      0
    end
  rescue NotImplementedError
    # Some cache stores raise NotImplementedError instead of just not supporting it
    0
  end

  # Warm cache by pre-computing values
  # @param keys_with_blocks [Hash] - mapping of cache keys to Procs/Lambdas
  # @param expires_in [ActiveSupport::Duration] - TTL for all entries
  #
  # Example:
  #   CacheService.warm_cache(
  #     "user:#{user.id}:profile" => -> { User.expensive_profile_calc(user) },
  #     "user:#{user.id}:recent_posts" => -> { user.posts.recent(10) }
  #   )
  def self.warm_cache(keys_with_blocks, expires_in: 1.hour)
    keys_with_blocks.each do |key, block|
      # Convert lambda/proc to block for fetch_cached
      fetch_cached(key, expires_in: expires_in) { block.call }
    end
  end

  # Clear all cache entries (use with caution in production!)
  # @return [Boolean] - true if successful
  def self.clear_all
    cache_store.clear
  end

  # Get cache statistics (if supported by cache store)
  # @return [Hash] - cache statistics or empty hash if unsupported
  def self.stats
    return {} unless cache_store.respond_to?(:stats)

    cache_store.stats
  end

  # Check if key exists in cache
  # @param key [String] - cache key
  # @return [Boolean] - true if key exists
  def self.exists?(key)
    cache_store.exist?(key)
  end

  # Get raw value from cache without generating if missing
  # @param key [String] - cache key
  # @return [Object, nil] - cached value or nil
  def self.read(key)
    cache_store.read(key)
  end

  # Write value directly to cache
  # @param key [String] - cache key
  # @param value [Object] - value to cache
  # @param expires_in [ActiveSupport::Duration] - TTL (default: 1 hour)
  # @return [Object] - the cached value
  def self.write(key, value, expires_in: 1.hour)
    cache_store.write(key, value, expires_in: expires_in)
    value
  end

  # Delete specific cache key
  # @param key [String] - cache key
  # @return [Boolean] - true if key was deleted
  def self.delete(key)
    cache_store.delete(key)
  end
end
