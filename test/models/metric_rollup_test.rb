require "test_helper"

class MetricRollupTest < ActiveSupport::TestCase
  def setup
    # Clean up any test data
    MetricRollup.delete_all
    Alert.delete_all
  end

  # Test validations
  test "requires metric_name" do
    rollup = MetricRollup.new(
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {sum: 100}
    )
    assert_not rollup.valid?
    assert rollup.errors[:metric_name].present?
  end

  test "requires metric_type" do
    rollup = MetricRollup.new(
      metric_name: "api.requests",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {sum: 100}
    )
    assert_not rollup.valid?
    assert rollup.errors[:metric_type].present?
  end

  test "requires valid metric_type" do
    rollup = MetricRollup.new(
      metric_name: "api.requests",
      metric_type: "invalid",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {sum: 100}
    )
    assert_not rollup.valid?
    assert rollup.errors[:metric_type].present?
  end

  test "requires valid rollup_interval" do
    rollup = MetricRollup.new(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "monthly",
      aggregated_at: Time.current,
      statistics: {sum: 100}
    )
    assert_not rollup.valid?
    assert rollup.errors[:rollup_interval].present?
  end

  test "requires sample_count to be non-negative" do
    rollup = MetricRollup.new(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {sum: 100},
      sample_count: -1
    )
    assert_not rollup.valid?
    assert rollup.errors[:sample_count].present?
  end

  # Test creation
  test "creates valid counter rollup" do
    rollup = MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {sum: 500, count: 1},
      sample_count: 1
    )
    assert_predicate rollup, :persisted?
    assert_equal "api.requests", rollup.metric_name
    assert_equal "counter", rollup.metric_type
  end

  test "creates valid gauge rollup" do
    rollup = MetricRollup.create!(
      metric_name: "cache.hit_rate",
      metric_type: "gauge",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {avg: 0.85, min: 0.75, max: 0.95, latest: 0.90},
      sample_count: 1
    )
    assert_predicate rollup, :persisted?
    assert_equal 0.85, rollup.statistics["avg"]
  end

  test "creates valid histogram rollup" do
    rollup = MetricRollup.create!(
      metric_name: "api.response_time",
      metric_type: "histogram",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {count: 100, min: 10, max: 500, mean: 145.5, p50: 120, p95: 400, p99: 480},
      sample_count: 100
    )
    assert_predicate rollup, :persisted?
    assert_equal 100, rollup.statistics["count"]
    assert_equal 400, rollup.statistics["p95"]
  end

  # Test scopes
  test "by_metric scope filters by metric name" do
    now = Time.current
    MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: now,
      statistics: {sum: 500, count: 1},
      sample_count: 1
    )

    MetricRollup.create!(
      metric_name: "cache.hit_rate",
      metric_type: "gauge",
      rollup_interval: "hourly",
      aggregated_at: now,
      statistics: {avg: 0.85, min: 0.75, max: 0.95, latest: 0.90},
      sample_count: 1
    )

    rollups = MetricRollup.by_metric("api.requests")
    assert_equal 1, rollups.count
    assert_equal "api.requests", rollups.first.metric_name
  end

  test "by_type scope filters by metric type" do
    now = Time.current
    MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: now,
      statistics: {sum: 500},
      sample_count: 1
    )

    MetricRollup.create!(
      metric_name: "cache.hit_rate",
      metric_type: "gauge",
      rollup_interval: "hourly",
      aggregated_at: now,
      statistics: {avg: 0.85},
      sample_count: 1
    )

    rollups = MetricRollup.by_type("gauge")
    assert_equal 1, rollups.count
    assert_equal "gauge", rollups.first.metric_type
  end

  test "by_interval scope filters by rollup interval" do
    now = Time.current
    MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: now,
      statistics: {sum: 500},
      sample_count: 1
    )

    MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "daily",
      aggregated_at: now,
      statistics: {sum: 12000},
      sample_count: 24
    )

    rollups = MetricRollup.by_interval("hourly")
    assert_equal 1, rollups.count
    assert_equal "hourly", rollups.first.rollup_interval
  end

  test "since scope filters by time" do
    now = Time.current
    hour_ago = now - 1.hour

    MetricRollup.create!(
      metric_name: "metric1",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: now,
      statistics: {sum: 100},
      sample_count: 1
    )

    MetricRollup.create!(
      metric_name: "metric2",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: hour_ago,
      statistics: {sum: 100},
      sample_count: 1
    )

    cutoff = now - 30.minutes
    rollups = MetricRollup.since(cutoff)
    assert_equal 1, rollups.count
    assert rollups.all? { |r| r.aggregated_at >= cutoff }
  end

  test "for_metric scope returns metric with all intervals" do
    now = Time.current
    MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: now,
      statistics: {sum: 500},
      sample_count: 1
    )

    MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "daily",
      aggregated_at: now - 1.day,
      statistics: {sum: 12000},
      sample_count: 24
    )

    rollups = MetricRollup.for_metric("api.requests")
    assert_equal 2, rollups.count
    assert rollups.map(&:rollup_interval).include?("hourly")
    assert rollups.map(&:rollup_interval).include?("daily")
  end

  test "older_than scope returns only old records" do
    now = Time.current
    cutoff = now - 30.minutes

    MetricRollup.create!(
      metric_name: "recent",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: now,
      statistics: {sum: 100},
      sample_count: 1
    )

    MetricRollup.create!(
      metric_name: "old",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: cutoff - 1.minute,
      statistics: {sum: 100},
      sample_count: 1
    )

    rollups = MetricRollup.older_than(cutoff)
    assert_equal 1, rollups.count
    assert rollups.all? { |r| r.aggregated_at < cutoff }
  end

  # Test class methods
  test "latest_for returns the latest rollup for metric and interval" do
    now = Time.current
    hour_ago = now - 1.hour

    MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: hour_ago,
      statistics: {sum: 400},
      sample_count: 1
    )

    MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: now,
      statistics: {sum: 500},
      sample_count: 1
    )

    rollup = MetricRollup.latest_for("api.requests", "hourly")
    assert_equal 500, rollup.statistics["sum"]
  end

  test "cleanup_old_metrics deletes old records" do
    old_rollup = MetricRollup.create!(
      metric_name: "old.metric",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: 10.days.ago,
      statistics: {sum: 100},
      sample_count: 1
    )

    recent_rollup = MetricRollup.create!(
      metric_name: "recent.metric",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {sum: 100},
      sample_count: 1
    )

    initial_count = MetricRollup.count
    deleted = MetricRollup.cleanup_old_metrics(7)
    final_count = MetricRollup.count

    assert_equal 1, deleted
    assert_equal initial_count - 1, final_count
    assert_not MetricRollup.exists?(old_rollup.id)
    assert MetricRollup.exists?(recent_rollup.id)
  end

  test "average_statistic calculates average across rollups" do
    MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {sum: 500, count: 1},
      sample_count: 1
    )

    MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current - 1.hour,
      statistics: {sum: 400, count: 1},
      sample_count: 1
    )

    avg = MetricRollup.average_statistic("api.requests", "sum", "hourly", 10)
    expected = (500 + 400) / 2.0
    assert_equal expected.round(2), avg
  end

  # Test instance methods
  test "exceeds_threshold? returns true when max exceeds threshold" do
    rollup = MetricRollup.create!(
      metric_name: "api.response_time",
      metric_type: "histogram",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {count: 100, min: 10, max: 500, mean: 145.5, p95: 400},
      sample_count: 100
    )

    assert rollup.exceeds_threshold?(300)
    assert_not rollup.exceeds_threshold?(600)
  end

  test "below_threshold? returns true when avg is below threshold" do
    rollup = MetricRollup.create!(
      metric_name: "cache.hit_rate",
      metric_type: "gauge",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {avg: 0.85, min: 0.75, max: 0.95, latest: 0.90},
      sample_count: 1
    )

    assert rollup.below_threshold?(0.9)
    assert_not rollup.below_threshold?(0.8)
  end

  test "summary returns human-readable string for counter" do
    rollup = MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {sum: 500, count: 1},
      sample_count: 1
    )

    summary = rollup.summary
    assert summary.include?("500")
    assert summary.include?("Total")
  end

  test "summary returns human-readable string for gauge" do
    rollup = MetricRollup.create!(
      metric_name: "cache.hit_rate",
      metric_type: "gauge",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {avg: 0.85, min: 0.75, max: 0.95, latest: 0.90},
      sample_count: 1
    )

    summary = rollup.summary
    assert summary.include?("0.85")
    assert summary.include?("Avg")
  end

  test "percent_change_from_previous calculates percentage change" do
    MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current - 1.hour,
      statistics: {sum: 500},
      sample_count: 1
    )

    new_rollup = MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {sum: 600},
      sample_count: 1
    )

    # Percent change = ((600 - 500) / 500) * 100 = 20%
    percent_change = new_rollup.percent_change_from_previous
    assert_equal 20.0, percent_change
  end

  test "percent_change_from_previous returns nil when no previous" do
    rollup = MetricRollup.create!(
      metric_name: "new.metric",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {sum: 100},
      sample_count: 1
    )

    assert_nil rollup.percent_change_from_previous
  end

  # Test edge cases
  test "handles statistics with minimal data" do
    rollup = MetricRollup.create!(
      metric_name: "test.metric",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {sum: 1},
      sample_count: 0
    )
    assert_predicate rollup, :persisted?
    assert_equal 1, rollup.statistics["sum"]
  end

  test "handles very large numbers" do
    rollup = MetricRollup.create!(
      metric_name: "big.numbers",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {sum: 999_999_999_999},
      sample_count: 1
    )
    assert_equal 999_999_999_999, rollup.statistics["sum"]
  end

  test "handles floating point precision" do
    rollup = MetricRollup.create!(
      metric_name: "precise.metric",
      metric_type: "gauge",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {avg: 0.123456789},
      sample_count: 1
    )
    assert_equal 0.123456789, rollup.statistics["avg"]
  end

  test "handles nil values in statistics" do
    rollup = MetricRollup.create!(
      metric_name: "sparse.metric",
      metric_type: "histogram",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {count: 0, min: nil, max: nil, p95: nil},
      sample_count: 0
    )
    assert_nil rollup.statistics["min"]
    assert_nil rollup.statistics["max"]
  end

  test "extract_comparable_value returns sum for counter" do
    rollup = MetricRollup.create!(
      metric_name: "api.requests",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {sum: 100, count: 5},
      sample_count: 5
    )
    assert_equal 100, rollup.extract_comparable_value
  end

  test "extract_comparable_value returns avg for gauge" do
    rollup = MetricRollup.create!(
      metric_name: "cache.hit_rate",
      metric_type: "gauge",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {avg: 0.95, latest: 0.90},
      sample_count: 1
    )
    assert_equal 0.95, rollup.extract_comparable_value
  end

  test "extract_comparable_value returns mean for histogram" do
    rollup = MetricRollup.create!(
      metric_name: "api.response_time",
      metric_type: "histogram",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {mean: 150.5, sum: 15050, count: 100},
      sample_count: 100
    )
    assert_equal 150.5, rollup.extract_comparable_value
  end

  test "extract_comparable_value handles missing fields gracefully" do
    rollup = MetricRollup.create!(
      metric_name: "sparse.metric",
      metric_type: "gauge",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {latest: 42},
      sample_count: 1
    )
    assert_equal 42, rollup.extract_comparable_value
  end

  test "percent_change_from_previous returns nil when previous_val is zero" do
    MetricRollup.create!(
      metric_name: "zero.metric",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current - 1.hour,
      statistics: {sum: 0},
      sample_count: 0
    )

    rollup = MetricRollup.create!(
      metric_name: "zero.metric",
      metric_type: "counter",
      rollup_interval: "hourly",
      aggregated_at: Time.current,
      statistics: {sum: 100},
      sample_count: 1
    )

    assert_nil rollup.percent_change_from_previous
  end
end
