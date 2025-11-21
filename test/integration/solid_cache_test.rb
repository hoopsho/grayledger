require "test_helper"

class SolidCacheTest < ActionDispatch::IntegrationTest
  test "solid cache stores and retrieves values" do
    # Write to cache
    Rails.cache.write("test_key", "test_value", expires_in: 1.hour)
    
    # Read from cache
    cached_value = Rails.cache.read("test_key")
    assert_equal "test_value", cached_value
  end

  test "solid cache expires values" do
    # Write with 1 second expiry
    Rails.cache.write("expiring_key", "value", expires_in: 1.second)
    
    # Should exist immediately
    assert_equal "value", Rails.cache.read("expiring_key")
    
    # Wait for expiry
    sleep 2
    
    # Should be gone
    assert_nil Rails.cache.read("expiring_key")
  end

  test "solid cache handles complex objects" do
    user_data = { id: 1, name: "John Doe", email: "john@example.com" }
    Rails.cache.write("user_1", user_data, expires_in: 1.hour)
    
    cached = Rails.cache.read("user_1")
    assert_equal user_data, cached
  end

  test "solid cache handles fetch with block" do
    # First fetch should execute block
    value = Rails.cache.fetch("fetch_test", expires_in: 1.hour) do
      "computed_value"
    end
    assert_equal "computed_value", value
    
    # Second fetch should return cached value (not re-execute block)
    value2 = Rails.cache.fetch("fetch_test", expires_in: 1.hour) do
      "different_value"
    end
    assert_equal "computed_value", value2
  end

  test "solid cache delete works" do
    Rails.cache.write("deletable", "value")
    assert_equal "value", Rails.cache.read("deletable")
    
    Rails.cache.delete("deletable")
    assert_nil Rails.cache.read("deletable")
  end
end
