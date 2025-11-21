class AlertMailer < ApplicationMailer
  default from: "alerts@grayledger.local"

  def critical_threshold_alert(metric_name, current_value, threshold, alert_type = nil)
    @metric_name = metric_name
    @current_value = current_value
    @threshold = threshold
    @alert_type = alert_type || "critical"
    @timestamp = Time.current

    # Format values for display based on metric type
    @formatted_value = format_value(current_value, metric_name)
    @formatted_threshold = format_value(threshold, metric_name)

    mail(
      to: admin_email,
      subject: "ALERT: #{@metric_name} exceeded critical threshold"
    )
  end

  private

  def admin_email
    ENV.fetch("ALERT_EMAIL", "admin@grayledger.local")
  end

  def format_value(value, metric_name)
    case metric_name
    when "error_rate", "cache_hit_rate"
      "#{(value * 100).round(2)}%"
    when "job_failures"
      "#{value.to_i} failures/hr"
    else
      value.to_s
    end
  end
end
