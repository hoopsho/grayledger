require "test_helper"

class AlertTest < ActiveSupport::TestCase
  test "creates valid alert with all attributes" do
    alert = Alert.new(
      alert_type: Alert::ALERT_TYPES[:error_rate],
      metric_name: "error_rate",
      current_value: 0.08,
      threshold: 0.05,
      triggered_at: Time.current,
      description: "Error rate exceeded"
    )

    assert alert.valid?
    assert alert.save
  end

  test "validates presence of required fields" do
    alert = Alert.new

    assert alert.invalid?
    assert alert.errors[:alert_type].present?
    assert alert.errors[:metric_name].present?
    assert alert.errors[:current_value].present?
    assert alert.errors[:threshold].present?
    assert alert.errors[:triggered_at].present?
  end

  test "validates alert_type inclusion" do
    alert = Alert.new(
      alert_type: "invalid_type",
      metric_name: "test",
      current_value: 1,
      threshold: 0.5,
      triggered_at: Time.current
    )

    assert alert.invalid?
    assert alert.errors[:alert_type].present?
  end

  test "validates triggered_at cannot be in future" do
    alert = Alert.new(
      alert_type: Alert::ALERT_TYPES[:error_rate],
      metric_name: "error_rate",
      current_value: 0.08,
      threshold: 0.05,
      triggered_at: 1.hour.from_now
    )

    assert alert.invalid?
    assert alert.errors[:triggered_at].present?
  end

  test "validates resolved_at must be after triggered_at" do
    now = Time.current
    alert = Alert.new(
      alert_type: Alert::ALERT_TYPES[:error_rate],
      metric_name: "error_rate",
      current_value: 0.08,
      threshold: 0.05,
      triggered_at: now,
      resolved_at: now - 1.hour
    )

    assert alert.invalid?
    assert alert.errors[:resolved_at].present?
  end

  test "resolve! marks alert as resolved" do
    alert = Alert.create!(
      alert_type: Alert::ALERT_TYPES[:error_rate],
      metric_name: "error_rate",
      current_value: 0.08,
      threshold: 0.05,
      triggered_at: Time.current
    )

    assert_nil alert.resolved_at
    assert alert.active?

    alert.resolve!

    assert alert.resolved_at.present?
    assert !alert.active?
  end

  test "active scope returns only unresolved alerts" do
    alert1 = Alert.create!(
      alert_type: Alert::ALERT_TYPES[:error_rate],
      metric_name: "error_rate",
      current_value: 0.08,
      threshold: 0.05,
      triggered_at: Time.current
    )

    alert2 = Alert.create!(
      alert_type: Alert::ALERT_TYPES[:cache_hit_rate],
      metric_name: "cache_hit_rate",
      current_value: 0.70,
      threshold: 0.80,
      triggered_at: Time.current
    )

    alert2.resolve!

    active = Alert.active
    assert_equal 1, active.count
    assert_includes active.pluck(:id), alert1.id
    refute_includes active.pluck(:id), alert2.id
  end

  test "resolved scope returns only resolved alerts" do
    alert1 = Alert.create!(
      alert_type: Alert::ALERT_TYPES[:error_rate],
      metric_name: "error_rate",
      current_value: 0.08,
      threshold: 0.05,
      triggered_at: Time.current
    )

    alert2 = Alert.create!(
      alert_type: Alert::ALERT_TYPES[:cache_hit_rate],
      metric_name: "cache_hit_rate",
      current_value: 0.70,
      threshold: 0.80,
      triggered_at: Time.current
    )

    alert2.resolve!

    resolved = Alert.resolved
    assert_equal 1, resolved.count
    assert_includes resolved.pluck(:id), alert2.id
    refute_includes resolved.pluck(:id), alert1.id
  end

  test "by_type scope filters by alert type" do
    Alert.create!(
      alert_type: Alert::ALERT_TYPES[:error_rate],
      metric_name: "error_rate",
      current_value: 0.08,
      threshold: 0.05,
      triggered_at: Time.current
    )

    Alert.create!(
      alert_type: Alert::ALERT_TYPES[:cache_hit_rate],
      metric_name: "cache_hit_rate",
      current_value: 0.70,
      threshold: 0.80,
      triggered_at: Time.current
    )

    error_rate_alerts = Alert.by_type(Alert::ALERT_TYPES[:error_rate])
    assert_equal 1, error_rate_alerts.count
  end

  test "by_metric scope filters by metric name" do
    Alert.create!(
      alert_type: Alert::ALERT_TYPES[:error_rate],
      metric_name: "error_rate",
      current_value: 0.08,
      threshold: 0.05,
      triggered_at: Time.current
    )

    Alert.create!(
      alert_type: Alert::ALERT_TYPES[:cache_hit_rate],
      metric_name: "cache_hit_rate",
      current_value: 0.70,
      threshold: 0.80,
      triggered_at: Time.current
    )

    error_rate_alerts = Alert.by_metric("error_rate")
    assert_equal 1, error_rate_alerts.count
  end

  test "rate_limit_exceeded? prevents duplicate alerts within window" do
    alert = Alert.create!(
      alert_type: Alert::ALERT_TYPES[:error_rate],
      metric_name: "error_rate",
      current_value: 0.08,
      threshold: 0.05,
      triggered_at: Time.current
    )

    # Should return true when recent alert exists within window
    assert Alert.rate_limit_exceeded?(
      Alert::ALERT_TYPES[:error_rate],
      "error_rate",
      1.hour  # 1 hour window, alert is recent
    )

    # Create an old alert (outside the window)
    old_alert = Alert.create!(
      alert_type: Alert::ALERT_TYPES[:cache_hit_rate],
      metric_name: "cache_hit_rate",
      current_value: 0.70,
      threshold: 0.80,
      triggered_at: 2.hours.ago
    )

    # Should return false for old alert outside small window
    assert !Alert.rate_limit_exceeded?(
      Alert::ALERT_TYPES[:cache_hit_rate],
      "cache_hit_rate",
      1.hour  # 1 hour window, alert is 2 hours old
    )
  end

  test "duration calculates time alert was active" do
    triggered_at = 10.minutes.ago
    alert = Alert.create!(
      alert_type: Alert::ALERT_TYPES[:error_rate],
      metric_name: "error_rate",
      current_value: 0.08,
      threshold: 0.05,
      triggered_at: triggered_at
    )

    duration = alert.duration
    assert duration >= 10.minutes
    assert duration < 11.minutes
  end

  test "check_threshold triggers alert when error rate exceeds threshold" do
    Alert.check_threshold(
      Alert::ALERT_TYPES[:error_rate],
      "error_rate",
      0.08,  # 8% error rate
      0.05   # 5% threshold
    )

    alert = Alert.active.first
    assert alert.present?
    assert_equal 0.08, alert.current_value.to_f
    assert_equal 0.05, alert.threshold.to_f
  end

  test "check_threshold triggers alert when cache hit rate falls below threshold" do
    Alert.check_threshold(
      Alert::ALERT_TYPES[:cache_hit_rate],
      "cache_hit_rate",
      0.70,  # 70% hit rate
      0.80   # 80% threshold
    )

    alert = Alert.active.first
    assert alert.present?
    assert_equal 0.70, alert.current_value.to_f
    assert_equal 0.80, alert.threshold.to_f
  end

  test "check_threshold triggers alert when job failures exceed threshold" do
    Alert.check_threshold(
      Alert::ALERT_TYPES[:job_failures],
      "job_failures",
      15,  # 15 failures per hour
      10   # 10 threshold
    )

    alert = Alert.active.first
    assert alert.present?
    assert_equal 15, alert.current_value.to_f.to_i
    assert_equal 10, alert.threshold.to_f.to_i
  end

  test "check_threshold respects rate limiting" do
    # Create first alert
    Alert.check_threshold(
      Alert::ALERT_TYPES[:error_rate],
      "error_rate",
      0.08,
      0.05
    )

    assert_equal 1, Alert.active.count

    # Try to create a second alert within rate limit window
    Alert.check_threshold(
      Alert::ALERT_TYPES[:error_rate],
      "error_rate",
      0.10,
      0.05
    )

    # Should still be only one alert (rate limited)
    assert_equal 1, Alert.active.count
  end

  test "check_threshold resolves active alerts when threshold is met" do
    alert = Alert.create!(
      alert_type: Alert::ALERT_TYPES[:error_rate],
      metric_name: "error_rate",
      current_value: 0.08,
      threshold: 0.05,
      triggered_at: Time.current
    )

    assert alert.active?

    # Check threshold with value below threshold
    Alert.check_threshold(
      Alert::ALERT_TYPES[:error_rate],
      "error_rate",
      0.03,  # Below threshold
      0.05
    )

    alert.reload
    assert !alert.active?
    assert alert.resolved_at.present?
  end

  test "check_threshold uses provided description" do
    description = "Custom error message"

    Alert.check_threshold(
      Alert::ALERT_TYPES[:error_rate],
      "error_rate",
      0.08,
      0.05,
      description
    )

    alert = Alert.active.first
    assert_equal description, alert.description
  end
end
