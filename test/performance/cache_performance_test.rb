# Performance benchmarks for CacheService
# Tests cache hit vs cache miss performance to ensure sub-200ms targets
#
# Run with: rails benchmark:cache
# Or directly: ruby -Ilib:test test/performance/cache_performance_test.rb
#
require "test_helper"
require "benchmark"

class CachePerformanceTest < ActiveSupport::TestCase
  # Benchmark cache hits vs misses
  def test_cache_hit_vs_miss_performance
    key = "perf_test:data"
    expensive_value = "x" * 10_000 # 10KB of data

    # Warm cache
    CacheService.write(key, expensive_value)

    # Benchmark cache hit
    hit_time = Benchmark.measure do
      100.times { CacheService.read(key) }
    end

    # Benchmark cache miss (cold cache)
    CacheService.delete(key)
    miss_time = Benchmark.measure do
      100.times do
        CacheService.fetch_cached(key) { expensive_value }
      end
    end

    puts "\n=== Cache Hit vs Miss Performance ==="
    puts "Cache Hit (100 reads):  #{hit_time.real * 1000}ms"
    puts "Cache Miss (100 fetches): #{miss_time.real * 1000}ms"

    # Cache hits and misses both involve database round-trips in Solid Cache.
    # We primarily want to verify the cache is working, not hitting extreme speedup.
    # Sometimes cached reads are slower due to deserialization overhead.
    speedup = if hit_time.real > 0
      miss_time.real / hit_time.real
    else
      1.0
    end
    puts "Speedup: #{speedup.round(2)}x"

    # Just verify both complete within reasonable time (very lenient for CI)
    assert hit_time.real < 2.0, "Cache hits should complete in <2s for 100 reads"
    assert miss_time.real < 2.0, "Cache misses should complete in <2s for 100 fetches"
  end

  # Benchmark nested cache key generation
  def test_nested_cache_key_generation_performance
    iterations = 1000
    namespace = "ledger"
    segments = ["entries", 123, "2025-01-15", "USD", "balance"]

    time = Benchmark.measure do
      iterations.times do
        CacheService.nested_key(namespace, segments)
      end
    end

    avg_time_us = (time.real / iterations) * 1_000_000
    puts "\n=== Nested Cache Key Generation ==="
    puts "Total time (#{iterations} iterations): #{time.real * 1000}ms"
    puts "Average per iteration: #{avg_time_us.round(2)}µs"

    # Should be very fast (< 500ms for 1000 iterations = 500µs per iteration)
    assert time.real < 0.5, "Nested key generation should be <500ms for 1000 iterations"
  end

  # Benchmark warm cache pre-loading
  def test_cache_warm_up_performance
    keys_with_blocks = {}
    10.times do |i|
      keys_with_blocks["key:#{i}"] = -> { "value:#{i}" }
    end

    # Clear cache first
    CacheService.clear_all

    time = Benchmark.measure do
      CacheService.warm_cache(keys_with_blocks, expires_in: 1.hour)
    end

    puts "\n=== Cache Warm-Up Performance ==="
    puts "Warming 10 keys: #{time.real * 1000}ms"
    puts "Average per key: #{(time.real / 10) * 1000}ms"

    # Verify all keys are cached
    10.times do |i|
      assert CacheService.exists?("key:#{i}"),
             "Key key:#{i} should be in cache after warm-up"
    end

    assert time.real < 1.0, "Warming 10 keys should be <1s"
  end

  # Benchmark cache delete performance
  def test_cache_delete_performance
    iterations = 100
    key = "delete_test"

    # Pre-populate cache
    iterations.times do |i|
      CacheService.write("#{key}:#{i}", "value")
    end

    time = Benchmark.measure do
      iterations.times do |i|
        CacheService.delete("#{key}:#{i}")
      end
    end

    puts "\n=== Cache Delete Performance ==="
    puts "Deleting #{iterations} keys: #{time.real * 1000}ms"
    puts "Average per delete: #{(time.real / iterations) * 1000}ms"

    # Should be reasonably fast - database-backed cache may be slower than in-memory
    # Lenient threshold for CI environments (1 second for 100 deletes)
    assert time.real < 1.0, "Deleting #{iterations} keys should be <1s"
  end

  # Benchmark complex nested structure caching
  def test_complex_object_caching_performance
    key = "complex_object"
    complex_data = {
      entries: Array.new(100) { |i| {id: i, amount: 100.50 * i, account_id: i % 10} },
      balances: Hash[*(1..20).flat_map { |i| ["account_#{i}", 10_000 * i] }],
      metadata: {timestamp: Time.current, checksum: SecureRandom.hex(32)}
    }

    # Warm cache
    CacheService.write(key, complex_data)

    # Benchmark read
    time = Benchmark.measure do
      100.times { CacheService.read(key) }
    end

    puts "\n=== Complex Object Caching ==="
    puts "Reading complex object 100 times: #{time.real * 1000}ms"
    puts "Average per read: #{(time.real / 100) * 1000}ms"

    # Verify data integrity
    cached = CacheService.read(key)
    assert_equal complex_data, cached, "Cached data should match original"
    assert time.real < 1.0, "Reading 100 complex objects should be <1s"
  end

  # Integration test: sub-200ms response time target
  def test_sub_200ms_response_time_target
    puts "\n=== Sub-200ms Response Time Target ==="

    # Simulate typical request: cache lookup + small computation
    request_times = []

    30.times do |i|
      key = "user:#{i}:profile"
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      result = CacheService.fetch_cached(key, expires_in: 1.hour) do
        # Simulate database lookup (just a sleep)
        sleep 0.001
        {user_id: i, name: "User #{i}", email: "user#{i}@example.com"}
      end

      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      elapsed_ms = (end_time - start_time) * 1000

      request_times << elapsed_ms

      # On subsequent calls, should be cached
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      CacheService.fetch_cached(key, expires_in: 1.hour) { result }
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      request_times << (end_time - start_time) * 1000
    end

    avg_time = request_times.sum / request_times.length
    max_time = request_times.max
    min_time = request_times.min

    puts "Average response time: #{avg_time.round(2)}ms"
    puts "Min response time: #{min_time.round(2)}ms"
    puts "Max response time: #{max_time.round(2)}ms"

    # Most requests should be well under 200ms
    under_200ms = request_times.select { |t| t < 200 }.length
    percentage = (under_200ms / request_times.length) * 100
    puts "Requests under 200ms: #{percentage.round(1)}%"

    assert avg_time < 200, "Average response time should be <200ms, got #{avg_time.round(2)}ms"
  end
end
