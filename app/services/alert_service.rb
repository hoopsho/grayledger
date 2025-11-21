class AlertService
  # Critical thresholds for monitoring
  CRITICAL_THRESHOLDS = {
    error_rate: {threshold: 0.05, description: "Error rate exceeds 5%"},
    cache_hit_rate: {threshold: 0.80, description: "Cache hit rate falls below 80%"},
    job_failures: {threshold: 10, description: "Job failure rate exceeds 10 per hour"}
  }.freeze

  # Rate limiting: max 1 alert per hour per alert type
  RATE_LIMIT_WINDOW = 1.hour

  def self.check_critical_thresholds(metrics)
    new.check_critical_thresholds(metrics)
  end

  def check_critical_thresholds(metrics)
    results = {
      triggered: [],
      rate_limited: [],
      resolved: []
    }

    # Check error rate threshold (should be < 5%)
    if metrics[:error_rate].present?
      result = check_error_rate(metrics[:error_rate])
      results[result[:status]] << result[:alert] if result[:alert]
    end

    # Check cache hit rate threshold (should be > 80%)
    if metrics[:cache_hit_rate].present?
      result = check_cache_hit_rate(metrics[:cache_hit_rate])
      results[result[:status]] << result[:alert] if result[:alert]
    end

    # Check job failures threshold (should be < 10/hr)
    if metrics[:job_failures].present?
      result = check_job_failures(metrics[:job_failures])
      results[result[:status]] << result[:alert] if result[:alert]
    end

    results
  end

  def check_error_rate(current_value)
    metric_name = "error_rate"
    alert_type = Alert::ALERT_TYPES[:error_rate]
    threshold = CRITICAL_THRESHOLDS[:error_rate][:threshold]

    if current_value > threshold
      if Alert.rate_limit_exceeded?(alert_type, metric_name, RATE_LIMIT_WINDOW)
        {
          status: :rate_limited,
          alert: {type: alert_type, metric: metric_name, value: current_value}
        }
      else
        alert = trigger_alert(
          alert_type,
          metric_name,
          current_value,
          threshold,
          "Error rate is #{(current_value * 100).round(2)}%, exceeds threshold of #{(threshold * 100).round(2)}%"
        )
        {
          status: :triggered,
          alert: alert
        }
      end
    else
      resolve_alerts(alert_type, metric_name)
      {
        status: :resolved,
        alert: {type: alert_type, metric: metric_name}
      }
    end
  end

  def check_cache_hit_rate(current_value)
    metric_name = "cache_hit_rate"
    alert_type = Alert::ALERT_TYPES[:cache_hit_rate]
    threshold = CRITICAL_THRESHOLDS[:cache_hit_rate][:threshold]

    if current_value < threshold
      if Alert.rate_limit_exceeded?(alert_type, metric_name, RATE_LIMIT_WINDOW)
        {
          status: :rate_limited,
          alert: {type: alert_type, metric: metric_name, value: current_value}
        }
      else
        alert = trigger_alert(
          alert_type,
          metric_name,
          current_value,
          threshold,
          "Cache hit rate is #{(current_value * 100).round(2)}%, falls below threshold of #{(threshold * 100).round(2)}%"
        )
        {
          status: :triggered,
          alert: alert
        }
      end
    else
      resolve_alerts(alert_type, metric_name)
      {
        status: :resolved,
        alert: {type: alert_type, metric: metric_name}
      }
    end
  end

  def check_job_failures(current_value)
    metric_name = "job_failures"
    alert_type = Alert::ALERT_TYPES[:job_failures]
    threshold = CRITICAL_THRESHOLDS[:job_failures][:threshold]

    if current_value > threshold
      if Alert.rate_limit_exceeded?(alert_type, metric_name, RATE_LIMIT_WINDOW)
        {
          status: :rate_limited,
          alert: {type: alert_type, metric: metric_name, value: current_value}
        }
      else
        alert = trigger_alert(
          alert_type,
          metric_name,
          current_value,
          threshold,
          "Job failures: #{current_value.to_i} per hour, exceeds threshold of #{threshold.to_i}"
        )
        {
          status: :triggered,
          alert: alert
        }
      end
    else
      resolve_alerts(alert_type, metric_name)
      {
        status: :resolved,
        alert: {type: alert_type, metric: metric_name}
      }
    end
  end

  private

  def trigger_alert(alert_type, metric_name, current_value, threshold, description)
    alert = Alert.create!(
      alert_type: alert_type,
      metric_name: metric_name,
      current_value: current_value,
      threshold: threshold,
      triggered_at: Time.current,
      description: description
    )

    # Send email notification (use deliver_now to support tests, but Rails.env.production? could use deliver_later)
    send_alert_email(metric_name, current_value, threshold, alert_type)

    alert
  end

  def resolve_alerts(alert_type, metric_name)
    Alert.active.by_type(alert_type).by_metric(metric_name).each(&:resolve!)
  end

  def send_alert_email(metric_name, current_value, threshold, alert_type)
    # Use deliver_now for synchronous delivery in tests/development
    # In production, consider switching to deliver_later with Solid Queue
    AlertMailer.critical_threshold_alert(
      metric_name,
      current_value,
      threshold,
      alert_type
    ).deliver_now
  end
end
