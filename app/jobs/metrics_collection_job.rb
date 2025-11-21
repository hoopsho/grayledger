class MetricsCollectionJob < ApplicationJob
  queue_as :default

  # Run every 5 minutes to check critical thresholds and trigger alerts
  # Scheduled via SolidQueue recurring task in config/recurring_jobs.yml or via console:
  #
  #   SolidQueue::RecurringTask.create!(
  #     key: "metrics_collection",
  #     class_name: "MetricsCollectionJob",
  #     schedule: "every 5 minutes"
  #   )

  def perform
    # Check critical thresholds and trigger alerts via AlertService
    check_critical_thresholds
  rescue => e
    Rails.logger.error("MetricsCollectionJob failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    raise
  end

  private

  # Check critical thresholds and trigger alerts via AlertService
  # This delegates threshold checking to the AlertService which handles:
  # - Rate limiting (1 alert per hour per metric)
  # - Email delivery
  # - Alert resolution when thresholds are met
  def check_critical_thresholds
    alert_metrics = extract_alert_metrics
    result = AlertService.check_critical_thresholds(alert_metrics)

    # Log alert summary
    if result[:triggered].any?
      Rails.logger.warn("Triggered #{result[:triggered].length} new alerts: #{result[:triggered].map { |a| a[:metric] }.join(", ")}")
    end

    if result[:rate_limited].any?
      Rails.logger.info("Rate limited #{result[:rate_limited].length} alerts: #{result[:rate_limited].map { |a| a[:metric] }.join(", ")}")
    end

    if result[:resolved].any?
      Rails.logger.info("Resolved #{result[:resolved].length} alerts")
    end
  rescue => e
    Rails.logger.error("Error checking critical thresholds: #{e.message}")
    # Don't raise - allow job to continue even if alerting fails
  end

  # Extract metrics relevant for alert checking
  def extract_alert_metrics
    {
      error_rate: calculate_error_rate,
      cache_hit_rate: calculate_cache_hit_rate,
      job_failures: calculate_job_failures
    }.compact
  end

  # Calculate error rate from tracked metrics
  # Uses database-backed Metric model
  def calculate_error_rate
    # Get latest error_rate metric if tracked
    error_metric = Metric.by_name("error_rate").order(recorded_at: :desc).first
    return error_metric.value.to_f if error_metric.present?

    # Otherwise calculate from error/request counters
    errors_metric = Metric.by_name("errors.total").order(recorded_at: :desc).first
    requests_metric = Metric.by_name("requests.total").order(recorded_at: :desc).first

    return nil unless errors_metric && requests_metric
    errors = errors_metric.value.to_f
    requests = requests_metric.value.to_f

    return nil if requests.zero?
    (errors / requests).round(4)
  rescue => e
    Rails.logger.warn("Error calculating error rate: #{e.message}")
    nil
  end

  # Calculate cache hit rate from tracked metrics
  def calculate_cache_hit_rate
    # Get latest cache_hit_rate metric if tracked
    cache_metric = Metric.by_name("cache.hit_rate").order(recorded_at: :desc).first
    return cache_metric.value.to_f if cache_metric.present?

    # Otherwise calculate from hits/misses counters
    hits_metric = Metric.by_name("cache.hits").order(recorded_at: :desc).first
    misses_metric = Metric.by_name("cache.misses").order(recorded_at: :desc).first

    return nil unless hits_metric && misses_metric
    hits = hits_metric.value.to_f
    misses = misses_metric.value.to_f
    total = hits + misses

    return nil if total.zero?
    (hits / total).round(4)
  rescue => e
    Rails.logger.warn("Error calculating cache hit rate: #{e.message}")
    nil
  end

  # Calculate job failures per hour
  def calculate_job_failures
    # Get latest job_failures_per_hour metric if tracked
    failures_metric = Metric.by_name("job_failures_per_hour").order(recorded_at: :desc).first
    return failures_metric.value.to_f if failures_metric.present?

    # Otherwise count from Solid Queue failed executions in past hour
    count_failed_jobs_per_hour
  rescue => e
    Rails.logger.warn("Error calculating job failures: #{e.message}")
    nil
  end

  # Count failed jobs in the past hour from Solid Queue
  def count_failed_jobs_per_hour
    require "solid_queue"
    SolidQueue::FailedExecution.where("created_at > ?", 1.hour.ago).count
  rescue => e
    Rails.logger.warn("Error counting failed jobs: #{e.message}")
    0
  end
end
