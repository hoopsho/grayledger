# Benchmark tasks for performance testing
namespace :benchmark do
  desc "Run cache performance benchmarks"
  task cache: :environment do
    # Load test environment
    Rails.env = "test"
    Rails.cache.clear

    puts "Starting cache performance benchmarks..."
    puts "Cache store: #{Rails.cache.class.name}"
    puts "=" * 60

    # Define the test class inline to avoid test_helper loading issues
    class CachePerformanceTest
      def test_cache_hit_vs_miss_performance
        require "benchmark"
        key = "perf_test:data"
        expensive_value = "x" * 10_000

        # Warm cache
        CacheService.write(key, expensive_value)

        # Benchmark cache hit
        hit_time = Benchmark.measure do
          100.times { CacheService.read(key) }
        end

        # Benchmark cache miss
        CacheService.delete(key)
        miss_time = Benchmark.measure do
          100.times do
            CacheService.fetch_cached(key) { expensive_value }
          end
        end

        puts "\n=== Cache Hit vs Miss Performance ==="
        puts "Cache Hit (100 reads):        #{(hit_time.real * 1000).round(2)}ms"
        puts "Cache Miss (100 fetches):     #{(miss_time.real * 1000).round(2)}ms"

        speedup = miss_time.real / hit_time.real
        puts "Speedup: #{speedup.round(2)}x"

        unless hit_time.real < miss_time.real
          raise "Cache hits should be faster than misses"
        end
      end

      def test_nested_cache_key_generation_performance
        require "benchmark"
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
        puts "Total time (#{iterations} iterations): #{(time.real * 1000).round(2)}ms"
        puts "Average per iteration: #{avg_time_us.round(2)}µs"

        unless time.real < 0.1
          raise "Nested key generation should be <100ms for 1000 iterations"
        end
      end

      def test_cache_warm_up_performance
        require "benchmark"
        keys_with_blocks = {}
        10.times do |i|
          val = "value:#{i}"
          keys_with_blocks["key:#{i}"] = proc { val }
        end

        CacheService.clear_all

        time = Benchmark.measure do
          keys_with_blocks.each do |key, block|
            CacheService.fetch_cached(key, expires_in: 1.hour, &block)
          end
        end

        puts "\n=== Cache Warm-Up Performance ==="
        puts "Warming 10 keys: #{(time.real * 1000).round(2)}ms"
        puts "Average per key: #{((time.real / 10) * 1000).round(2)}ms"

        10.times do |i|
          unless CacheService.exists?("key:#{i}")
            raise "Key key:#{i} should be in cache after warm-up"
          end
        end

        # Solid Cache will be slower than memory store (database round-trip)
        # Accept up to 1 second for production cache writes
        unless time.real < 1.0
          raise "Warming 10 keys should be <1000ms"
        end
      end

      def test_cache_delete_performance
        require "benchmark"
        iterations = 100
        key = "delete_test"

        iterations.times do |i|
          CacheService.write("#{key}:#{i}", "value")
        end

        time = Benchmark.measure do
          iterations.times do |i|
            CacheService.delete("#{key}:#{i}")
          end
        end

        puts "\n=== Cache Delete Performance ==="
        puts "Deleting #{iterations} keys: #{(time.real * 1000).round(2)}ms"
        puts "Average per delete: #{((time.real / iterations) * 1000).round(3)}ms"

        # Solid Cache will be slower than memory store (database round-trip)
        # Accept up to 2 seconds for production cache deletes
        unless time.real < 2.0
          raise "Deleting #{iterations} keys should be <2000ms"
        end
      end

      def test_complex_object_caching_performance
        require "benchmark"
        key = "complex_object"
        complex_data = {
          entries: Array.new(100) { |i| {id: i, amount: 100.50 * i, account_id: i % 10} },
          balances: Hash[*(1..20).flat_map { |i| ["account_#{i}", 10_000 * i] }],
          metadata: {timestamp: Time.current, checksum: SecureRandom.hex(32)}
        }

        CacheService.write(key, complex_data)

        time = Benchmark.measure do
          100.times { CacheService.read(key) }
        end

        puts "\n=== Complex Object Caching ==="
        puts "Reading complex object 100 times: #{(time.real * 1000).round(2)}ms"
        puts "Average per read: #{((time.real / 100) * 1000).round(3)}ms"

        cached = CacheService.read(key)
        unless complex_data == cached
          raise "Cached data should match original"
        end

        # Solid Cache will be slower than memory store (database round-trip)
        # Accept up to 1 second for reading 100 complex objects
        unless time.real < 1.0
          raise "Reading 100 complex objects should be <1000ms"
        end
      end

      def test_sub_200ms_response_time_target
        puts "\n=== Sub-200ms Response Time Target ==="

        request_times = []

        30.times do |i|
          key = "user:#{i}:profile"
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          result = CacheService.fetch_cached(key, expires_in: 1.hour) do
            {user_id: i, name: "User #{i}", email: "user#{i}@example.com"}
          end

          end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          elapsed_ms = (end_time - start_time) * 1000
          request_times << elapsed_ms

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

        under_200ms = request_times.select { |t| t < 200 }.length
        percentage = (under_200ms / request_times.length) * 100
        puts "Requests under 200ms: #{percentage.round(1)}%"

        unless avg_time < 200
          puts "Warning: Average response time should be <200ms, got #{avg_time.round(2)}ms"
        end
      end
    end

    # Run tests
    test = CachePerformanceTest.new

    benchmark_tests = [
      :test_cache_hit_vs_miss_performance,
      :test_nested_cache_key_generation_performance,
      :test_cache_warm_up_performance,
      :test_cache_delete_performance,
      :test_complex_object_caching_performance,
      :test_sub_200ms_response_time_target
    ]

    results = {}
    passed = 0
    failed = 0

    benchmark_tests.each do |test_method|
      begin
        test.send(test_method)
        passed += 1
        results[test_method] = :passed
      rescue => e
        failed += 1
        results[test_method] = :failed
        puts "\nERROR in #{test_method}: #{e.message}"
      end
    end

    # Print summary
    puts "\n" + "=" * 60
    puts "Benchmark Results Summary"
    puts "=" * 60
    puts "Passed: #{passed}"
    puts "Failed: #{failed}"
    puts "Total: #{benchmark_tests.length}"

    if ENV["SAVE_RESULTS"]
      results_file = Rails.root.join("tmp/benchmark_results.txt")
      File.open(results_file, "w") do |f|
        f.puts "Cache Performance Benchmarks - #{Time.current}"
        f.puts "=" * 60
        f.puts "Cache store: #{Rails.cache.class.name}"
        f.puts ""
        f.puts results.map { |test, status| "#{test}: #{status}" }.join("\n")
      end
      puts "\nResults saved to #{results_file}"
    end

    exit(failed > 0 ? 1 : 0)
  end

  desc "Run all performance benchmarks"
  task all: :environment do
    puts "Running all performance benchmarks..."
    Rake::Task["benchmark:cache"].invoke
  end
end
