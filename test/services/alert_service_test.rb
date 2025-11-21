require "test_helper"

class AlertServiceTest < ActiveSupport::TestCase
  setup do
    @service = AlertService.new
    # Clear any existing alerts before each test
    Alert.delete_all
  end

  # Test: error_rate threshold checking
  test "check_error_rate triggers alert when error rate exceeds threshold" do
    result = @service.check_error_rate(0.08)  # 8% > 5% threshold

    assert_equal :triggered, result[:status]
    assert result[:alert]
    assert_equal 1, Alert.active.count
  end

  test "check_error_rate does not trigger alert when error rate is below threshold" do
    result = @service.check_error_rate(0.03)  # 3% < 5% threshold

    assert_equal :resolved, result[:status]
    assert_equal 0, Alert.active.count
  end

  test "check_error_rate rate limits alerts" do
    # First alert should trigger
    result1 = @service.check_error_rate(0.08)
    assert_equal :triggered, result1[:status]

    # Second alert within same hour should be rate limited
    result2 = @service.check_error_rate(0.10)
    assert_equal :rate_limited, result2[:status]

    # Only one alert should exist
    assert_equal 1, Alert.active.count
  end

  # Test: cache_hit_rate threshold checking
  test "check_cache_hit_rate triggers alert when cache hit rate falls below threshold" do
    result = @service.check_cache_hit_rate(0.70)  # 70% < 80% threshold

    assert_equal :triggered, result[:status]
    assert result[:alert]
    assert_equal 1, Alert.active.count
  end

  test "check_cache_hit_rate does not trigger alert when cache hit rate meets threshold" do
    result = @service.check_cache_hit_rate(0.85)  # 85% > 80% threshold

    assert_equal :resolved, result[:status]
    assert_equal 0, Alert.active.count
  end

  test "check_cache_hit_rate rate limits alerts" do
    # First alert should trigger
    result1 = @service.check_cache_hit_rate(0.70)
    assert_equal :triggered, result1[:status]

    # Second alert within same hour should be rate limited
    result2 = @service.check_cache_hit_rate(0.65)
    assert_equal :rate_limited, result2[:status]

    # Only one alert should exist
    assert_equal 1, Alert.active.count
  end

  # Test: job_failures threshold checking
  test "check_job_failures triggers alert when failures exceed threshold" do
    result = @service.check_job_failures(15)  # 15 > 10 threshold

    assert_equal :triggered, result[:status]
    assert result[:alert]
    assert_equal 1, Alert.active.count
  end

  test "check_job_failures does not trigger alert when failures below threshold" do
    result = @service.check_job_failures(5)  # 5 < 10 threshold

    assert_equal :resolved, result[:status]
    assert_equal 0, Alert.active.count
  end

  test "check_job_failures rate limits alerts" do
    # First alert should trigger
    result1 = @service.check_job_failures(15)
    assert_equal :triggered, result1[:status]

    # Second alert within same hour should be rate limited
    result2 = @service.check_job_failures(20)
    assert_equal :rate_limited, result2[:status]

    # Only one alert should exist
    assert_equal 1, Alert.active.count
  end

  # Test: check_critical_thresholds integration
  test "check_critical_thresholds with all metrics triggers all alerts" do
    metrics = {
      error_rate: 0.08,         # Exceeds 5%
      cache_hit_rate: 0.70,     # Below 80%
      job_failures: 15          # Exceeds 10
    }

    result = @service.check_critical_thresholds(metrics)

    assert_equal 3, result[:triggered].length
    assert_equal 0, result[:rate_limited].length
    assert_equal 0, result[:resolved].length
    assert_equal 3, Alert.active.count
  end

  test "check_critical_thresholds ignores missing metrics" do
    metrics = {
      error_rate: 0.08
    }

    result = @service.check_critical_thresholds(metrics)

    assert_equal 1, result[:triggered].length
    assert_equal 1, Alert.active.count
  end

  test "check_critical_thresholds resolves alerts when metrics improve" do
    # Create initial alerts
    metrics_bad = {
      error_rate: 0.08,
      cache_hit_rate: 0.70,
      job_failures: 15
    }
    @service.check_critical_thresholds(metrics_bad)
    assert_equal 3, Alert.active.count

    # Clear alerts and set rate limit window to 0 by skipping time
    Alert.delete_all

    # Re-create alerts but this time with better metrics (within rate limit window)
    # We need to use raw SQL to avoid rate limiting for this test
    Alert.create!(
      alert_type: Alert::ALERT_TYPES[:error_rate],
      metric_name: "error_rate",
      current_value: 0.08,
      threshold: 0.05,
      triggered_at: 2.hours.ago  # Old alert
    )

    metrics_good = {
      error_rate: 0.02,         # Below 5%
      cache_hit_rate: 0.85,     # Above 80%
      job_failures: 5           # Below 10
    }

    result = @service.check_critical_thresholds(metrics_good)

    # Should resolve the old alert
    assert Alert.active.count < 1 || Alert.unresolved_since(1.hour.ago).count == 0
  end

  # Test: email delivery
  test "triggering alert sends email" do
    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      @service.check_error_rate(0.08)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal ["alerts@grayledger.local"], email.from
  end

  test "alert email contains metric information" do
    @service.check_error_rate(0.08)

    email = ActionMailer::Base.deliveries.last
    assert email.subject.include?("error_rate")
    assert email.body.encoded.include?("8.0%")  # Formatted value
    assert email.body.encoded.include?("5.0%")  # Formatted threshold
  end

  test "rate limited alerts do not send email" do
    @service.check_error_rate(0.08)
    initial_count = ActionMailer::Base.deliveries.size

    @service.check_error_rate(0.10)

    # Should not have sent another email
    assert_equal initial_count, ActionMailer::Base.deliveries.size
  end

  test "resolved alerts do not send email" do
    initial_count = ActionMailer::Base.deliveries.size

    @service.check_error_rate(0.03)  # Below threshold, should resolve

    # Should not send email for resolved threshold
    assert_equal initial_count, ActionMailer::Base.deliveries.size
  end

  # Test: threshold calculation and formatting
  test "error rate is formatted as percentage in description" do
    @service.check_error_rate(0.084)  # 8.4%

    alert = Alert.active.first
    assert_includes alert.description, "8.4%"
  end

  test "cache hit rate is formatted as percentage in description" do
    @service.check_cache_hit_rate(0.756)  # 75.6%

    alert = Alert.active.first
    assert_includes alert.description, "75.6%"
  end

  test "job failures uses per hour units in description" do
    @service.check_job_failures(12.5)

    alert = Alert.active.first
    assert_includes alert.description, "12"
    assert_includes alert.description, "hour"
  end

  # Test: class method
  test "AlertService.check_critical_thresholds creates new instance" do
    metrics = {
      error_rate: 0.08
    }

    result = AlertService.check_critical_thresholds(metrics)

    assert_equal 1, result[:triggered].length
    assert_equal 1, Alert.active.count
  end

  # Test: multiple metrics of same type at different times
  test "different metrics can have independent alerts" do
    # Create alert for error_rate
    @service.check_error_rate(0.08)

    # Create alert for different metric but same alert type
    Alert.create!(
      alert_type: Alert::ALERT_TYPES[:error_rate],
      metric_name: "api_error_rate",  # Different metric name
      current_value: 0.07,
      threshold: 0.05,
      triggered_at: Time.current
    )

    active_alerts = Alert.active
    assert_equal 2, active_alerts.count
    assert_equal 2, active_alerts.select { |a| a.alert_type == Alert::ALERT_TYPES[:error_rate] }.count
  end

  # Test: alert attributes are set correctly
  test "triggered alert has correct attributes" do
    @service.check_error_rate(0.085)

    alert = Alert.active.first
    assert_equal Alert::ALERT_TYPES[:error_rate], alert.alert_type
    assert_equal "error_rate", alert.metric_name
    assert_equal 0.085, alert.current_value.to_f
    assert_equal 0.05, alert.threshold.to_f
    assert alert.triggered_at.present?
    assert_nil alert.resolved_at
    assert alert.description.present?
  end
end
