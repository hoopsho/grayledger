require "test_helper"

class MetricsTrackerTest < ActiveSupport::TestCase
  setup do
    # Clear all metrics before each test
    Metric.delete_all
  end

  teardown do
    # Clean up after tests
    Metric.delete_all
  end

  # Test: track_counter increments counter metrics
  test "track_counter creates counter metric" do
    metric = MetricsTracker.track_counter('entries_created', 1, company_id: 123)

    assert metric.present?
    assert_equal 'entries_created', metric.metric_name
    assert_equal 'counter', metric.metric_type
    assert_equal 1, metric.value
    assert_equal({ 'company_id' => 123 }, metric.tags)
  end

  # Test: track_counter with default value
  test "track_counter uses default value of 1" do
    metric = MetricsTracker.track_counter('daily_active_users')

    assert_equal 1, metric.value
  end

  # Test: track_counter with custom value
  test "track_counter accepts custom values" do
    metric = MetricsTracker.track_counter('batch_entries_created', 50)

    assert_equal 50, metric.value
  end

  # Test: track_gauge sets gauge metrics
  test "track_gauge creates gauge metric" do
    metric = MetricsTracker.track_gauge('cache_hit_rate', 0.95)

    assert metric.present?
    assert_equal 'cache_hit_rate', metric.metric_name
    assert_equal 'gauge', metric.metric_type
    assert_equal 0.95, metric.value.to_f
  end

  # Test: track_timing records timing metrics
  test "track_timing creates timing metric" do
    metric = MetricsTracker.track_timing('request_duration_ms', 125)

    assert metric.present?
    assert_equal 'request_duration_ms', metric.metric_name
    assert_equal 'timing', metric.metric_type
    assert_equal 125, metric.value
  end

  # Test: measure_timing automatically tracks execution time
  test "measure_timing tracks block execution time" do
    result = MetricsTracker.measure_timing('ai_categorization') do
      sleep 0.01  # Sleep 10ms
      'categorized'
    end

    assert_equal 'categorized', result

    metric = Metric.by_name('ai_categorization').last
    assert metric.present?
    assert_equal 'timing', metric.metric_type
    # Duration should be >= 10ms (accounting for execution time)
    assert metric.value >= 10
  end

  # Test: get_metric returns most recent metric
  test "get_metric returns most recent metric" do
    MetricsTracker.track_gauge('cache_hit_rate', 0.90)
    sleep 0.01
    MetricsTracker.track_gauge('cache_hit_rate', 0.95)

    metric = MetricsTracker.get_metric('cache_hit_rate')

    assert_equal 0.95, metric.value.to_f
  end

  # Test: sum_values aggregates counter values
  test "sum_values sums metric values" do
    MetricsTracker.track_counter('entries_created', 5)
    MetricsTracker.track_counter('entries_created', 3)
    MetricsTracker.track_counter('entries_created', 2)

    total = MetricsTracker.sum_values('entries_created')

    assert_equal 10.0, total
  end

  # Test: sum_values with tags
  test "sum_values filters by tags" do
    MetricsTracker.track_counter('revenue', 100, company_id: 1)
    MetricsTracker.track_counter('revenue', 200, company_id: 2)

    total = MetricsTracker.sum_values('revenue', tags: { company_id: 1 })

    assert_equal 100.0, total
  end

  # Test: avg_values calculates average
  test "avg_values calculates mean of metrics" do
    MetricsTracker.track_timing('response_time_ms', 100)
    MetricsTracker.track_timing('response_time_ms', 200)
    MetricsTracker.track_timing('response_time_ms', 300)

    average = MetricsTracker.avg_values('response_time_ms')

    assert_equal 200.0, average
  end

  # Test: min_values finds minimum
  test "min_values finds minimum metric value" do
    MetricsTracker.track_timing('response_time_ms', 100)
    MetricsTracker.track_timing('response_time_ms', 50)
    MetricsTracker.track_timing('response_time_ms', 200)

    minimum = MetricsTracker.min_values('response_time_ms')

    assert_equal 50, minimum
  end

  # Test: max_values finds maximum
  test "max_values finds maximum metric value" do
    MetricsTracker.track_timing('response_time_ms', 100)
    MetricsTracker.track_timing('response_time_ms', 50)
    MetricsTracker.track_timing('response_time_ms', 300)

    maximum = MetricsTracker.max_values('response_time_ms')

    assert_equal 300, maximum
  end

  test "count_by_day counts metrics per day" do
    # Create metrics for today
    MetricsTracker.track_counter('events', 1)
    MetricsTracker.track_counter('events', 1)
    MetricsTracker.track_counter('events', 1)

    daily_counts = MetricsTracker.count_by_day('events')

    assert daily_counts.key?(Date.current)
    assert_equal 3, daily_counts[Date.current]
  end

  # Test: sum_by_day sums metrics per day
  test "sum_by_day sums metric values per day" do
    MetricsTracker.track_counter('revenue', 100)
    MetricsTracker.track_counter('revenue', 200)
    MetricsTracker.track_counter('revenue', 150)

    daily_sums = MetricsTracker.sum_by_day('revenue')

    assert daily_sums.key?(Date.current)
    assert_equal 450.0, daily_sums[Date.current]
  end

  # Test: Thread safety - concurrent counter increments
  test "track_counter is thread-safe" do
    threads = 10.times.map do
      Thread.new do
        100.times { MetricsTracker.track_counter('thread_safe_counter', 1) }
      end
    end

    threads.each(&:join)

    total_count = Metric.by_name('thread_safe_counter').count
    # Should have 1000 metrics (10 threads * 100 increments)
    assert_equal 1000, total_count
  end

  # Test: Error handling - cleanup old metrics
  test "cleanup_old_metrics removes old entries" do
    # Create metric 31 days ago
    old_metric = Metric.create!(
      metric_name: 'old_event',
      metric_type: 'counter',
      value: 1,
      tags: {},
      recorded_at: 31.days.ago
    )

    # Create recent metric
    recent_metric = Metric.create!(
      metric_name: 'recent_event',
      metric_type: 'counter',
      value: 1,
      tags: {},
      recorded_at: Time.current
    )

    deleted_count = MetricsTracker.cleanup_old_metrics

    assert_equal 1, deleted_count
    assert_nil Metric.find_by(id: old_metric.id)
    assert Metric.find_by(id: recent_metric.id).present?
  end

  # Test: Business metric tracking - anomaly queue depth
  test "track_anomaly_queue_depth creates gauge metric" do
    metric = MetricsTracker.track_anomaly_queue_depth

    assert metric.present?
    assert_equal 'anomaly_queue_depth', metric.metric_name
    assert_equal 'gauge', metric.metric_type
  end

  # Test: Business metric tracking - AI confidence
  test "track_ai_confidence creates gauge metric" do
    metric = MetricsTracker.track_ai_confidence

    assert metric.present?
    assert_equal 'ai_confidence_avg_1h', metric.metric_name
    assert_equal 'gauge', metric.metric_type
  end

  # Test: Business metric tracking - entry posting success
  test "track_entry_posting_success creates gauge metric" do
    metric = MetricsTracker.track_entry_posting_success

    assert metric.present?
    assert_equal 'entry_posting_success_rate', metric.metric_name
    assert_equal 'gauge', metric.metric_type
  end

  # Test: Integration - realistic usage scenario
  test "integration - track daily active users with multiple events" do
    # Simulate multiple users creating entries throughout the day
    5.times do |user_id|
      3.times do |i|
        MetricsTracker.track_counter('entries_created', 1, user_id: user_id)
        MetricsTracker.track_timing('entry_creation_ms', 50 + rand(100), user_id: user_id)
      end
    end

    # Verify counters
    total_entries = MetricsTracker.sum_values('entries_created')
    assert_equal 15.0, total_entries

    # Verify timing statistics
    avg_time = MetricsTracker.avg_values('entry_creation_ms')
    assert avg_time > 50

    min_time = MetricsTracker.min_values('entry_creation_ms')
    max_time = MetricsTracker.max_values('entry_creation_ms')
    assert min_time <= avg_time
    assert avg_time <= max_time
  end

  # Test: Integration - per-company metrics tracking
  test "integration - track metrics per company with tag filtering" do
    # Company 1 activity
    3.times { MetricsTracker.track_counter('api_calls', 1, company_id: 1) }
    # Company 2 activity
    5.times { MetricsTracker.track_counter('api_calls', 1, company_id: 2) }

    company1_calls = MetricsTracker.sum_values('api_calls', tags: { company_id: 1 })
    company2_calls = MetricsTracker.sum_values('api_calls', tags: { company_id: 2 })

    assert_equal 3.0, company1_calls
    assert_equal 5.0, company2_calls
  end

  # Test: Scopes - filter by metric type
  test "metric scopes filter by type" do
    MetricsTracker.track_counter('counter_metric', 1)
    MetricsTracker.track_gauge('gauge_metric', 0.5)
    MetricsTracker.track_timing('timing_metric', 100)

    counters = Metric.counters
    gauges = Metric.gauges
    timings = Metric.timings

    assert_equal 1, counters.count
    assert_equal 1, gauges.count
    assert_equal 1, timings.count
  end

  # Test: Aggregation - sum with no data
  test "sum_values returns 0 when no metrics" do
    total = MetricsTracker.sum_values('nonexistent_metric')

    assert_equal 0.0, total
  end
end
