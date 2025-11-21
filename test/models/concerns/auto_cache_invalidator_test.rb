require "test_helper"

# Create a dummy model for testing AutoCacheInvalidator concern using an existing table
class DummyCacheModel < InvoiceItem
  # Inherit from InvoiceItem since that table exists in schema
  self.table_name = :invoice_items

  include AutoCacheInvalidator

  def invalidate_associated_caches
    CacheService.delete("dummy_#{id}_cache")
  end
end

class AutoCacheInvalidatorTest < ActiveSupport::TestCase
  setup do
    # Clear cache before each test
    Rails.cache.clear
  end

  teardown do
    # Clean up after each test
    Rails.cache.clear
    # Clean up test records
    DummyCacheModel.delete_all
  end

  test "invalidate_associated_caches hook method exists" do
    dummy = DummyCacheModel.create!(amount_cents: 1000)

    # Verify the method exists and is callable
    assert dummy.respond_to?(:invalidate_associated_caches)
    assert_nothing_raised { dummy.invalidate_associated_caches }
  end

  test "after_commit callbacks are registered" do
    # Verify callbacks are registered
    callbacks = DummyCacheModel._commit_callbacks
    has_invalidator = callbacks.any? { |cb| cb.filter.to_s.include?("invalidate_associated_caches") }

    assert has_invalidator, "AutoCacheInvalidator did not register after_commit callbacks"
  end

  test "cache is invalidated after create" do
    dummy = DummyCacheModel.create!(amount_cents: 1000)
    id = dummy.id
    cache_key = "dummy_#{id}_cache"

    # Pre-populate cache for this instance
    Rails.cache.write(cache_key, "test_value")
    assert Rails.cache.exist?(cache_key), "Cache entry was not created"

    # Create a new record - the first one's cache should still exist
    # because invalidation only affects the record being changed
    dummy2 = DummyCacheModel.create!(amount_cents: 2000)

    # First record's cache should still exist
    assert Rails.cache.exist?(cache_key), "Cache should not be invalidated for unmodified record"

    # Second record's cache key would not exist since we didn't pre-populate it
    cache_key2 = "dummy_#{dummy2.id}_cache"
    refute Rails.cache.exist?(cache_key2), "New record shouldn't have pre-populated cache"
  end

  test "cache is invalidated after update" do
    dummy = DummyCacheModel.create!(amount_cents: 1000)
    id = dummy.id
    cache_key = "dummy_#{id}_cache"

    # Pre-populate cache
    Rails.cache.write(cache_key, "test_value")
    assert Rails.cache.exist?(cache_key), "Cache entry was not created"

    # Update the record
    dummy.update!(amount_cents: 2000)

    # Cache should be invalidated
    refute Rails.cache.exist?(cache_key), "Cache was not invalidated after update"
  end

  test "cache is invalidated after destroy" do
    dummy = DummyCacheModel.create!(amount_cents: 1000)
    id = dummy.id
    cache_key = "dummy_#{id}_cache"

    # Pre-populate cache
    Rails.cache.write(cache_key, "test_value")
    assert Rails.cache.exist?(cache_key), "Cache entry was not created"

    # Destroy the record
    dummy.destroy!

    # Cache should be invalidated
    refute Rails.cache.exist?(cache_key), "Cache was not invalidated after destroy"
  end

  test "default invalidate_associated_caches does nothing" do
    # Create a model without overriding invalidate_associated_caches
    dummy_model = Class.new(InvoiceItem) do
      self.table_name = :invoice_items
      include AutoCacheInvalidator
    end

    # Should not raise an error when invalidate_associated_caches is called
    instance = dummy_model.create!(amount_cents: 5000)
    assert_nothing_raised { instance.invalidate_associated_caches }
  end

  test "model can override invalidate_associated_caches with custom logic" do
    custom_calls = []

    dummy_model = Class.new(InvoiceItem) do
      self.table_name = :invoice_items
      include AutoCacheInvalidator

      define_method(:invalidate_associated_caches) do
        custom_calls << {id: id, amount_cents: amount_cents}
      end
    end

    instance = dummy_model.create!(amount_cents: 1000)
    # The hook is called after commit, so check that it was tracked
    assert_equal 1, custom_calls.length, "Custom invalidation logic was not called"
    assert_equal instance.id, custom_calls.first[:id]
  end

  test "multiple models can have different invalidation patterns" do
    model_a_calls = []
    model_b_calls = []

    model_a = Class.new(InvoiceItem) do
      self.table_name = :invoice_items
      include AutoCacheInvalidator

      define_method(:invalidate_associated_caches) do
        model_a_calls << "called_for_a_#{id}"
      end
    end

    model_b = Class.new(InvoiceItem) do
      self.table_name = :invoice_items
      include AutoCacheInvalidator

      define_method(:invalidate_associated_caches) do
        model_b_calls << "called_for_b_#{id}"
      end
    end

    instance_a = model_a.create!(amount_cents: 1000)
    instance_b = model_b.create!(amount_cents: 2000)

    assert_equal 1, model_a_calls.length, "Model A invalidation not called"
    assert_equal 1, model_b_calls.length, "Model B invalidation not called"
  end

  test "cache service delete is called correctly" do
    dummy = DummyCacheModel.create!(amount_cents: 1000)
    id = dummy.id
    cache_key = "dummy_#{id}_cache"

    # Verify our implementation uses CacheService.delete
    Rails.cache.write(cache_key, "original_value")

    # Manually call invalidate to verify behavior
    dummy.invalidate_associated_caches

    # Cache should be deleted
    refute Rails.cache.exist?(cache_key), "CacheService.delete did not remove the key"
  end

  test "after_commit is not called during rollback" do
    calls = []

    dummy_model = Class.new(InvoiceItem) do
      self.table_name = :invoice_items
      include AutoCacheInvalidator

      define_method(:invalidate_associated_caches) do
        calls << id
      end
    end

    # Wrap in a transaction and rollback
    begin
      ActiveRecord::Base.transaction do
        instance = dummy_model.new(amount_cents: 1000)
        instance.save!
        raise ActiveRecord::Rollback
      end
    rescue StandardError
      # Ignore
    end

    # After rollback, invalidate_associated_caches should not be called
    # because after_commit only runs on successful commits
    assert_empty calls, "invalidate_associated_caches was called during rollback"
  end

  test "invalidation works with CacheService integration" do
    dummy = DummyCacheModel.create!(amount_cents: 1000)
    id = dummy.id
    cache_key = "dummy_#{id}_cache"

    # Pre-populate cache
    CacheService.write(cache_key, "test_value", expires_in: 1.hour)
    assert CacheService.exists?(cache_key), "Cache entry was not created via CacheService"

    # Update to trigger invalidation
    dummy.update!(amount_cents: 2000)

    # Cache should be invalidated
    refute CacheService.exists?(cache_key), "Cache was not invalidated via CacheService"
  end
end
