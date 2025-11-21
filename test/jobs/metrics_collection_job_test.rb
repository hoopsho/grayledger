require "test_helper"

class MetricsCollectionJobTest < ActiveSupport::TestCase
  setup do
    Alert.delete_all
    MetricRollup.delete_all
    Metric.delete_all
  end

  test "alert service triggers alert when error rate exceeds threshold" do
    assert_difference("ActionMailer::Base.deliveries.size") do
      AlertService.check_critical_thresholds({error_rate: 0.08})
    end

    alert = Alert.active.by_metric("error_rate").first
    assert alert.present?
    assert_equal 0.08, alert.current_value.to_f
  end

  test "alert service triggers alert when cache hit rate falls below threshold" do
    assert_difference("ActionMailer::Base.deliveries.size") do
      AlertService.check_critical_thresholds({cache_hit_rate: 0.70})
    end

    alert = Alert.active.by_metric("cache_hit_rate").first
    assert alert.present?
    assert_equal 0.70, alert.current_value.to_f
  end

  test "alert service triggers alert for job failures" do
    assert_difference("ActionMailer::Base.deliveries.size") do
      AlertService.check_critical_thresholds({job_failures: 15})
    end

    alert = Alert.active.by_metric("job_failures").first
    assert alert.present?
    assert_equal 15, alert.current_value.to_f.to_i
  end

  test "alert service resolves alerts when metrics improve" do
    # Create an alert first
    alert = Alert.create!(
      alert_type: Alert::ALERT_TYPES[:error_rate],
      metric_name: "error_rate",
      current_value: 0.10,
      threshold: 0.05,
      triggered_at: 2.hours.ago
    )

    assert alert.active?

    # Now run alert checking with improved metrics
    AlertService.check_critical_thresholds({error_rate: 0.02})

    alert.reload
    assert !alert.active?, "Alert should be resolved"
  end

  test "alert service respects rate limiting" do
    initial_count = ActionMailer::Base.deliveries.size

    # First alert should trigger
    AlertService.check_critical_thresholds({error_rate: 0.08})
    assert_equal initial_count + 1, ActionMailer::Base.deliveries.size

    # Second alert within rate limit should be rate limited
    AlertService.check_critical_thresholds({error_rate: 0.10})
    assert_equal initial_count + 1, ActionMailer::Base.deliveries.size, "No email should be sent for rate-limited alert"
  end

  test "alert service handles missing metrics gracefully" do
    assert_no_difference("Alert.count") do
      AlertService.check_critical_thresholds({})
    end
  end

  test "alert service triggers multiple alerts for different metrics" do
    assert_difference("ActionMailer::Base.deliveries.size", 3) do
      AlertService.check_critical_thresholds({
        error_rate: 0.10,
        cache_hit_rate: 0.70,
        job_failures: 15
      })
    end

    assert_equal 3, Alert.active.count
  end

  test "metrics collection job can run without tracked metrics" do
    assert_nothing_raised do
      MetricsCollectionJob.perform_now
    end
  end

  test "alert system sends email with correct content" do
    AlertService.check_critical_thresholds({error_rate: 0.08})

    email = ActionMailer::Base.deliveries.last
    assert_equal ["alerts@grayledger.local"], email.from
    assert email.subject.include?("error_rate")
  end

  test "alert system does not send email for threshold met" do
    initial_count = ActionMailer::Base.deliveries.size

    AlertService.check_critical_thresholds({error_rate: 0.02})  # Below threshold

    assert_equal initial_count, ActionMailer::Base.deliveries.size
  end

  test "multiple thresholds can be checked independently" do
    # Trigger error_rate alert
    AlertService.check_critical_thresholds({error_rate: 0.08})
    assert_equal 1, Alert.active.count

    # Trigger cache_hit_rate alert
    AlertService.check_critical_thresholds({cache_hit_rate: 0.70})
    assert_equal 2, Alert.active.count

    # Trigger job_failures alert
    AlertService.check_critical_thresholds({job_failures: 15})
    assert_equal 3, Alert.active.count
  end

  test "metrics collection job calculates error rate from database metrics" do
    Metric.track_counter("requests.total", 100)
    Metric.track_counter("errors.total", 8)

    job = MetricsCollectionJob.new
    error_rate = job.send(:calculate_error_rate)

    assert_equal 0.08, error_rate
  end

  test "metrics collection job calculates cache hit rate from database metrics" do
    Metric.track_counter("cache.hits", 80)
    Metric.track_counter("cache.misses", 20)

    job = MetricsCollectionJob.new
    cache_rate = job.send(:calculate_cache_hit_rate)

    assert_equal 0.8, cache_rate
  end
end
