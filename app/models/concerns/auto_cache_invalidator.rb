# AutoCacheInvalidator Concern - Automatic Cache Busting on Model Changes
#
# This concern provides a pattern for automatically invalidating associated caches
# when records are created, updated, or destroyed.
#
# To use this pattern:
# 1. Include this concern in your models
# 2. Override the `invalidate_associated_caches` method in your model
# 3. Use CacheService.delete or CacheService.delete_pattern to clear specific cache keys
#
# Example Model Setup:
#
#   class Account < ApplicationRecord
#     include AutoCacheInvalidator
#
#     def invalidate_associated_caches
#       # Invalidate this account's balance cache
#       CacheService.delete("account_#{id}_balance")
#       # Invalidate parent company's summary cache
#       CacheService.delete("company_#{company_id}_summary")
#     end
#   end
#
# When an account is saved or destroyed, the cache invalidation is triggered automatically.
#
module AutoCacheInvalidator
  extend ActiveSupport::Concern

  included do
    # Callback to invalidate caches after record is committed to database
    # Using after_commit ensures we only invalidate after the transaction is complete
    after_commit :invalidate_associated_caches, on: [:create, :update, :destroy]
  end

  # Override this method in your model to define cache invalidation strategy
  #
  # This method is called automatically after save and destroy via after_commit hooks.
  # Subclasses should override this to invalidate their specific cache patterns.
  #
  # @return [void]
  #
  # Example implementation:
  #   def invalidate_associated_caches
  #     CacheService.delete("user_#{user_id}_profile")
  #     CacheService.delete("company_#{company_id}_summary")
  #   end
  def invalidate_associated_caches
    # Default implementation: do nothing
    # Subclasses should override this method to define their cache invalidation logic
  end
end
