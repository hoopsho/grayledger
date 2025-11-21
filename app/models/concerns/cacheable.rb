# Cacheable Concern - Enables Russian Doll Caching for Models
#
# Russian doll caching uses nested fragment caches where invalidation cascades
# from parent to child records automatically via Rails' touch mechanism.
#
# To use this pattern:
# 1. Include this concern in your models
# 2. Add `touch: true` to belongs_to associations that should invalidate parent caches
# 3. Ensure models have `updated_at` timestamp columns (Rails default)
# 4. Use the cache_helper methods to wrap view sections
#
# Example Model Setup:
#
#   class Invoice < ApplicationRecord
#     include Cacheable
#     belongs_to :user, touch: true
#     has_many :line_items, dependent: :destroy
#   end
#
#   class LineItem < ApplicationRecord
#     include Cacheable
#     belongs_to :invoice, touch: true
#   end
#
# When a line item is updated:
# 1. LineItem#updated_at is updated
# 2. Invoice#updated_at is touched (updated) via touch: true
# 3. All fragment caches for Invoice are invalidated
#
# For more aggressive cache invalidation patterns, see AutoCacheInvalidator concern
# which automatically busts caches on model changes using CacheService.
#
module Cacheable
  extend ActiveSupport::Concern

  included do
    # Include AutoCacheInvalidator to handle automatic cache invalidation
    include AutoCacheInvalidator

    # Ensure the model responds to cache_key_with_version
    # This is available by default in Rails 6+, but we're explicit here
    validates :updated_at, presence: true
  end

  class_methods do
    # Return all cache dependencies for this model
    # Useful for testing and debugging cache invalidation
    #
    # @return [Hash] hash of association names and their touch status
    #
    # Example:
    #   Invoice.cache_dependencies
    #   # => { user: true, line_items: false }
    def cache_dependencies
      reflections.select { |_name, reflection| reflection.options[:touch] }
    end

    # Find all models that touch this model
    # Useful for understanding cache invalidation chains
    #
    # @return [Array<String>] class names that have touch: true for this model
    #
    # Example (in Invoice):
    #   Invoice.cache_dependents
    #   # => ["LineItem", "InvoicePayment"]
    def cache_dependents
      # This would need to be manually maintained or use reflection
      # Included for documentation purposes
      []
    end
  end

  # Instance method to get all child records that might be cached
  # Useful for manual cache busting in edge cases
  #
  # @return [Array<ActiveRecord::Base>] all associated records
  #
  # Example:
  #   invoice.cached_children
  #   # => [#<LineItem>, #<LineItem>, ...]
  def cached_children
    # Get all has_many associations
    self.class.reflections.values
      .select { |r| r.is_a?(ActiveRecord::Reflection::HasManyReflection) }
      .flat_map { |r| send(r.name) }
  end

  # Manually bust this record's cache and all parent caches
  # Usually not needed since touch: true handles it, but useful for edge cases
  #
  # Example:
  #   invoice.bust_cache!
  #   # Clears all fragments for this invoice and touches parents
  def bust_cache!
    # Update the timestamp to invalidate all cache_key_with_version derivatives
    update_column(:updated_at, Time.current)

    # Also touch parent records if this model belongs_to something with touch: true
    self.class.reflections.each do |_name, reflection|
      if reflection.is_a?(ActiveRecord::Reflection::BelongsToReflection) &&
         reflection.options[:touch]
        parent = send(reflection.name)
        parent&.update_column(:updated_at, Time.current)
      end
    end
  end

  # Get the cache version for this record
  # Combines the record's class, ID, and updated_at timestamp
  #
  # @return [String] the cache key with version
  #
  # Example:
  #   invoice.cache_version
  #   # => "invoices/123-20251121T123456Z"
  def cache_version
    cache_key_with_version
  end

  # Check if this record has been updated since a given time
  # Useful for validating whether cache is still valid
  #
  # @param time [Time] the time to compare against
  # @return [Boolean] true if record was updated after the given time
  #
  # Example:
  #   cache_generated_at = 1.hour.ago
  #   if invoice.updated_since?(cache_generated_at)
  #     Rails.cache.delete(cache_key)
  #   end
  def updated_since?(time)
    updated_at > time
  end

  # Override cache invalidation for aggressive cache busting
  # This is called automatically by AutoCacheInvalidator after commit
  #
  # Subclasses can override this to implement custom cache invalidation logic
  # beyond the Russian doll pattern.
  #
  # Example in a model:
  #   def invalidate_associated_caches
  #     # Invalidate this record's specific cache keys
  #     CacheService.delete("invoice_#{id}_summary")
  #     # Invalidate parent company's aggregates
  #     CacheService.delete_pattern("company_#{company_id}_*")
  #   end
  def invalidate_associated_caches
    # Default: just rely on touch-based Russian doll caching
    # Override in subclass if you need explicit CacheService invalidation
  end
end
