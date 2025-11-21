require "test_helper"

class CacheServiceTest < ActiveSupport::TestCase
  setup do
    # Clear cache before each test
    Rails.cache.clear
  end

  teardown do
    # Clean up after tests
    Rails.cache.clear
  end

  # Test: fetch_cached returns cached value
  test "fetch_cached returns cached value on subsequent calls" do
    call_count = 0
    key = "test_key_fetch_cached"

    # First call - computes and caches
    value1 = CacheService.fetch_cached(key) do
      call_count += 1
      "result_#{call_count}"
    end

    assert_equal "result_1", value1
    assert_equal 1, call_count

    # Second call - returns cached value without executing block
    value2 = CacheService.fetch_cached(key) do
      call_count += 1
      "result_#{call_count}"
    end

    assert_equal "result_1", value2
    assert_equal 1, call_count, "Block should not be called again for cache hit"
  end

  # Test: fetch_cached computes on cache miss
  test "fetch_cached computes value on cache miss" do
    computed_value = "expensive_result"
    key = "miss_key"

    value = CacheService.fetch_cached(key) do
      computed_value
    end

    assert_equal computed_value, value
    assert CacheService.exists?(key)
  end

  # Test: fetch_cached respects expires_in parameter
  test "fetch_cached respects expires_in parameter" do
    key = "expiring_key"
    value = CacheService.fetch_cached(key, expires_in: 5.seconds) do
      "expires_soon"
    end

    assert_equal "expires_soon", value
    assert CacheService.exists?(key)

    # Wait for expiration
    sleep 6

    # Key should be expired (cached value gone)
    assert !CacheService.exists?(key), "Key should expire after 5 seconds"
  end

  # Test: fetch_cached with force_miss
  test "fetch_cached with force_miss skips cache" do
    call_count = 0
    key = "force_miss_key"

    # First call - caches the value
    value1 = CacheService.fetch_cached(key) do
      call_count += 1
      "result_#{call_count}"
    end
    assert_equal "result_1", value1

    # Second call with force_miss: true - recomputes
    value2 = CacheService.fetch_cached(key, force_miss: true) do
      call_count += 1
      "result_#{call_count}"
    end

    assert_equal "result_2", value2
    assert_equal 2, call_count, "Block should be called again with force_miss"
  end

  # Test: nested_key generates proper cache keys
  test "nested_key generates formatted cache keys" do
    key = CacheService.nested_key("user", ["posts", 123, "trending"])
    assert_equal "user:posts:123:trending", key
  end

  # Test: nested_key handles nil values
  test "nested_key skips nil values" do
    key = CacheService.nested_key("user", ["posts", nil, 123])
    assert_equal "user:posts:123", key
  end

  # Test: nested_key with empty segments
  test "nested_key handles empty segments" do
    key = CacheService.nested_key("prefix", [])
    assert_equal "prefix", key
  end

  # Test: delete_pattern functionality
  test "delete_pattern handles unsupported stores gracefully" do
    # Store multiple keys
    CacheService.write("user:1:profile", "profile_1")
    CacheService.write("user:1:posts", "posts_1")
    CacheService.write("user:2:profile", "profile_2")

    # Delete pattern should not raise error
    result = CacheService.delete_pattern("user:1:*")

    # Solid Cache returns 0 (not supported)
    assert_equal 0, result
  end

  # Test: warm_cache pre-computes and caches values
  test "warm_cache pre-computes and caches multiple values" do
    call_count = 0

    keys_with_blocks = {
      "key1" => lambda {
        call_count += 1
        "value_1"
      },
      "key2" => lambda {
        call_count += 1
        "value_2"
      }
    }

    CacheService.warm_cache(keys_with_blocks)

    assert_equal 2, call_count

    # Verify values are cached
    assert_equal "value_1", CacheService.read("key1")
    assert_equal "value_2", CacheService.read("key2")
  end

  # Test: warm_cache with expires_in
  test "warm_cache respects expires_in parameter" do
    keys_with_blocks = {
      "warm_key" => lambda { "warm_value" }
    }

    CacheService.warm_cache(keys_with_blocks, expires_in: 5.seconds)

    assert CacheService.exists?("warm_key")

    sleep 6

    assert !CacheService.exists?("warm_key"), "Warmed cache should expire"
  end

  # Test: clear_all removes all cache entries
  test "clear_all removes all cache entries" do
    CacheService.write("key1", "value1")
    CacheService.write("key2", "value2")
    CacheService.write("key3", "value3")

    assert CacheService.exists?("key1")
    assert CacheService.exists?("key2")
    assert CacheService.exists?("key3")

    CacheService.clear_all

    assert !CacheService.exists?("key1")
    assert !CacheService.exists?("key2")
    assert !CacheService.exists?("key3")
  end

  # Test: exists? checks cache key existence
  test "exists? returns true for cached keys" do
    key = "existence_check"
    CacheService.write(key, "value")

    assert CacheService.exists?(key)
  end

  # Test: exists? returns false for missing keys
  test "exists? returns false for missing keys" do
    assert !CacheService.exists?("nonexistent_key")
  end

  # Test: read returns cached value
  test "read returns cached value" do
    key = "read_test"
    value = "cached_value"
    CacheService.write(key, value)

    result = CacheService.read(key)
    assert_equal value, result
  end

  # Test: read returns nil for missing keys
  test "read returns nil for missing keys" do
    result = CacheService.read("missing_key")
    assert_nil result
  end

  # Test: write stores values in cache
  test "write stores and returns value" do
    key = "write_test"
    value = {data: "test"}

    result = CacheService.write(key, value)

    assert_equal value, result
    assert_equal value, CacheService.read(key)
  end

  # Test: write respects expires_in
  test "write respects expires_in parameter" do
    key = "write_expires"
    value = "expiring_value"

    CacheService.write(key, value, expires_in: 5.seconds)

    assert CacheService.exists?(key)

    sleep 6

    assert !CacheService.exists?(key)
  end

  # Test: delete removes specific cache key
  test "delete removes specific cache key" do
    key = "delete_test"
    CacheService.write(key, "value")

    assert CacheService.exists?(key)

    result = CacheService.delete(key)

    assert result
    assert !CacheService.exists?(key)
  end

  # Test: delete returns false for missing keys
  test "delete returns false for nonexistent keys" do
    result = CacheService.delete("nonexistent_key")
    assert !result
  end

  # Test: stats returns hash or empty hash
  test "stats returns statistics" do
    stats = CacheService.stats
    assert_kind_of Hash, stats
  end

  # Test: fetch_cached with complex object
  test "fetch_cached handles complex objects" do
    key = "complex_object"
    complex_value = {user_id: 1, posts: [1, 2, 3]}

    result = CacheService.fetch_cached(key) do
      complex_value
    end

    assert_equal complex_value, result
    cached = CacheService.read(key)
    assert_equal complex_value, cached
  end

  # Test: fetch_cached with no block executes block
  test "fetch_cached with no block uses nil as cache miss" do
    key = "no_block_test"

    # Without block, fetch should work but cache nil
    result = CacheService.fetch_cached(key) do
      nil
    end

    assert_nil result
  end

  # Test: Integration - cache pattern for account balance
  test "integration - cache pattern for expensive calculation" do
    call_count = 0
    account_id = 123

    # Simulate expensive balance calculation
    def calculate_balance(account_id)
      # Simulate expensive query
      1000 + (account_id * 10)
    end

    # First call - computes balance
    balance1 = CacheService.fetch_cached(
      CacheService.nested_key("account", [account_id, "balance"]),
      expires_in: 15.minutes
    ) do
      call_count += 1
      calculate_balance(account_id)
    end

    assert_equal 2230, balance1
    assert_equal 1, call_count

    # Second call - uses cached value
    balance2 = CacheService.fetch_cached(
      CacheService.nested_key("account", [account_id, "balance"]),
      expires_in: 15.minutes
    ) do
      call_count += 1
      calculate_balance(account_id)
    end

    assert_equal 2230, balance2
    assert_equal 1, call_count, "Should use cached balance"
  end

  # Test: Integration - warming multiple report caches
  test "integration - warming multiple report caches" do
    company_id = 1
    cache_hits = {}

    keys_to_warm = {
      CacheService.nested_key("report", [company_id, "revenue"]) => lambda {
        cache_hits["revenue"] = true
        12345.67
      },
      CacheService.nested_key("report", [company_id, "expenses"]) => lambda {
        cache_hits["expenses"] = true
        5432.10
      },
      CacheService.nested_key("report", [company_id, "profit"]) => lambda {
        cache_hits["profit"] = true
        6913.57
      }
    }

    CacheService.warm_cache(keys_to_warm)

    assert cache_hits["revenue"]
    assert cache_hits["expenses"]
    assert cache_hits["profit"]

    # Verify cached values
    revenue = CacheService.read(CacheService.nested_key("report", [company_id, "revenue"]))
    assert_equal 12345.67, revenue
  end
end
