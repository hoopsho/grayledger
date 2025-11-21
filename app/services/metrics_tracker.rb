# MetricsTracker provides a thread-safe service for tracking business metrics
# Leverages PostgreSQL for storage, supporting counter, gauge, and timing metric types
#
# Philosophy: Track business-critical metrics in the database, enabling:
# - Queryable audit trail of system behavior
# - No external service dependencies (no external APM until justified by revenue)
# - Easy integration with Rails observability
#
# Usage:
#   # Track entry creation
#   MetricsTracker.track_counter('entries_created', 1, company_id: company.id)
#
#   # Track cache hit rate
#   MetricsTracker.track_gauge('cache_hit_rate', 0.95)
#
#   # Track request duration
#   MetricsTracker.track_timing('request_duration_ms', 125, endpoint: '/api/entries')
#
#   # Measure execution time automatically
#   result = MetricsTracker.measure_timing('ai_categorization') do
#     AiCategorizer.categorize(transaction)
#   end
#
#   # Query metrics
#   MetricsTracker.get_metric('cache_hit_rate')
#   MetricsTracker.avg_value('request_duration_ms', 1.hour.ago)
#   MetricsTracker.percentile('request_duration_ms', 95, 1.hour.ago)

class MetricsTracker
  # Track a counter metric (increment-only)
  # @param metric_name [String] - descriptive metric name (e.g., "entries_created", "daily_active_users")
  # @param value [Numeric] - amount to increment (default: 1)
  # @param tags [Hash] - optional tags for filtering (e.g., { company_id: 1, user_id: 2 })
  # @return [Metric] - created metric record
  def self.track_counter(metric_name, value = 1, tags = {})
    Metric.track_counter(metric_name, value, tags)
  rescue StandardError => e
    log_metric_error(metric_name, 'counter', e)
    nil
  end

  # Track a gauge metric (current value)
  # @param metric_name [String] - descriptive metric name (e.g., "cache_hit_rate", "memory_usage_percent")
  # @param value [Numeric] - current gauge value
  # @param tags [Hash] - optional tags for filtering
  # @return [Metric] - created metric record
  def self.track_gauge(metric_name, value, tags = {})
    Metric.track_gauge(metric_name, value, tags)
  rescue StandardError => e
    log_metric_error(metric_name, 'gauge', e)
    nil
  end

  # Track a timing metric (duration in milliseconds)
  # @param metric_name [String] - descriptive metric name (e.g., "request_duration_ms", "db_query_time_ms")
  # @param duration_ms [Numeric] - duration in milliseconds
  # @param tags [Hash] - optional tags for filtering
  # @return [Metric] - created metric record
  def self.track_timing(metric_name, duration_ms, tags = {})
    Metric.track_timing(metric_name, duration_ms, tags)
  rescue StandardError => e
    log_metric_error(metric_name, 'timing', e)
    nil
  end

  # Automatically measure execution time of a block and track as timing metric
  # @param metric_name [String] - name of the metric
  # @param tags [Hash] - optional tags
  # @return [Object] - return value of the block
  #
  # Example:
  #   result = MetricsTracker.measure_timing('ai_categorization', company_id: 1) do
  #     AiCategorizer.categorize(transaction)
  #   end
  def self.measure_timing(metric_name, tags = {}, &block)
    Metric.measure_timing(metric_name, tags, &block)
  rescue StandardError => e
    log_metric_error(metric_name, 'timing', e)
    block.call if block_given?
  end

  # Get the most recent metric value
  # @param metric_name [String] - name of the metric
  # @param tags [Hash] - optional tags to filter by
  # @return [Metric, nil] - most recent metric or nil
  def self.get_metric(metric_name, tags = {})
    Metric.get_metric(metric_name, tags)
  rescue StandardError => e
    log_metric_error(metric_name, 'query', e)
    nil
  end

  # Get all metrics for a given name in a time range
  # @param metric_name [String] - name of the metric
  # @param start_time [DateTime] - start of time range
  # @param end_time [DateTime] - end of time range (default: now)
  # @param tags [Hash] - optional tags to filter by
  # @return [Array<Metric>] - matching metrics
  def self.get_metrics_in_range(metric_name, start_time, end_time = Time.current, tags = {})
    Metric.get_metrics_in_range(metric_name, start_time, end_time, tags).to_a
  rescue StandardError => e
    log_metric_error(metric_name, 'range_query', e)
    []
  end

  # Calculate sum of all values for a metric
  # @param metric_name [String] - name of the metric
  # @param start_time [DateTime] - optional start time
  # @param end_time [DateTime] - optional end time
  # @param tags [Hash] - optional tags to filter by
  # @return [Float] - sum of metric values
  def self.sum_values(metric_name, start_time: nil, end_time: nil, tags: {})
    Metric.sum_values(metric_name, start_time, end_time, tags)
  rescue StandardError => e
    log_metric_error(metric_name, 'sum_aggregation', e)
    0.0
  end

  # Calculate average of all values for a metric
  # @param metric_name [String] - name of the metric
  # @param start_time [DateTime] - optional start time
  # @param end_time [DateTime] - optional end time
  # @param tags [Hash] - optional tags to filter by
  # @return [Float] - average of metric values
  def self.avg_values(metric_name, start_time: nil, end_time: nil, tags: {})
    Metric.avg_values(metric_name, start_time, end_time, tags)
  rescue StandardError => e
    log_metric_error(metric_name, 'avg_aggregation', e)
    0.0
  end

  # Get minimum value for a metric
  # @param metric_name [String] - name of the metric
  # @param start_time [DateTime] - optional start time
  # @param end_time [DateTime] - optional end time
  # @param tags [Hash] - optional tags to filter by
  # @return [Numeric] - minimum metric value
  def self.min_values(metric_name, start_time: nil, end_time: nil, tags: {})
    Metric.min_values(metric_name, start_time, end_time, tags)
  rescue StandardError => e
    log_metric_error(metric_name, 'min_aggregation', e)
    nil
  end

  # Get maximum value for a metric
  # @param metric_name [String] - name of the metric
  # @param start_time [DateTime] - optional start time
  # @param end_time [DateTime] - optional end time
  # @param tags [Hash] - optional tags to filter by
  # @return [Numeric] - maximum metric value
  def self.max_values(metric_name, start_time: nil, end_time: nil, tags: {})
    Metric.max_values(metric_name, start_time, end_time, tags)
  rescue StandardError => e
    log_metric_error(metric_name, 'max_aggregation', e)
    nil
  end

  # Calculate percentile for a metric
  # @param metric_name [String] - name of the metric
  # @param percentile [Integer] - percentile to calculate (1-100, default: 50)
  # @param start_time [DateTime] - optional start time
  # @param end_time [DateTime] - optional end time
  # @param tags [Hash] - optional tags to filter by
  # @return [Float] - value at the given percentile
  #
  # Example:
  #   p95_latency = MetricsTracker.percentile('request_duration_ms', 95, 1.hour.ago)
  def self.percentile(metric_name, percentile = 50, start_time = nil, end_time = nil, tags = {})
    Metric.percentile(metric_name, percentile, start_time, end_time, tags)
  rescue StandardError => e
    log_metric_error(metric_name, 'percentile_aggregation', e)
    nil
  end

  # Count metrics by day
  # @param metric_name [String] - name of the metric
  # @param start_date [Date] - optional start date
  # @param end_date [Date] - optional end date (default: today)
  # @param tags [Hash] - optional tags to filter by
  # @return [Hash] - { date => count, ... }
  #
  # Example:
  #   daily_users = MetricsTracker.count_by_day('daily_active_users', 7.days.ago)
  def self.count_by_day(metric_name, start_date = nil, end_date = nil, tags = {})
    Metric.count_by_day(metric_name, start_date, end_date, tags)
  rescue StandardError => e
    log_metric_error(metric_name, 'count_by_day', e)
    {}
  end

  # Sum metrics by day
  # @param metric_name [String] - name of the metric
  # @param start_date [Date] - optional start date
  # @param end_date [Date] - optional end date (default: today)
  # @param tags [Hash] - optional tags to filter by
  # @return [Hash] - { date => sum, ... }
  #
  # Example:
  #   daily_entries = MetricsTracker.sum_by_day('entries_created', 7.days.ago)
  def self.sum_by_day(metric_name, start_date = nil, end_date = nil, tags = {})
    Metric.sum_by_day(metric_name, start_date, end_date, tags)
  rescue StandardError => e
    log_metric_error(metric_name, 'sum_by_day', e)
    {}
  end

  # Track API response time for performance monitoring [TASK-6.4]
  # @param duration_ms [Numeric] - response time in milliseconds
  # @param tags [Hash] - optional tags (e.g., { endpoint: '/api/entries', method: 'POST' })
  # @return [Metric, nil] - created metric or nil on error
  def self.track_api_response_time(duration_ms, tags = {})
    track_timing('request_duration_ms', duration_ms, tags)
  end

  # Track business-critical metrics (called by MetricsCollectionJob every 5 minutes)

  # Track anomaly queue depth
  # @return [Metric, nil] - created metric or nil on error
  def self.track_anomaly_queue_depth
    track_gauge('anomaly_queue_depth', 0, source: 'metrics_collection_job')
  end

  # Track AI confidence score (average of recent entries)
  # @return [Metric, nil] - created metric or nil on error
  def self.track_ai_confidence
    avg_confidence = 95.0  # Placeholder - would calculate from actual entries
    track_gauge('ai_confidence_avg_1h', avg_confidence, source: 'metrics_collection_job')
  end

  # Track entry posting success rate
  # @return [Metric, nil] - created metric or nil on error
  def self.track_entry_posting_success
    success_rate = 100.0  # Placeholder - would calculate from actual entries
    track_gauge('entry_posting_success_rate', success_rate, source: 'metrics_collection_job')
  end

  # Track cache statistics
  # @return [Metric, nil] - created metric or nil on error
  def self.track_cache_statistics
    cache_stats = Rails.cache.stats
    if cache_stats.present?
      hit_rate = cache_stats[:get_hits].to_f / (cache_stats[:get_hits] + cache_stats[:get_misses]) if cache_stats[:get_hits]
      track_gauge('cache_hit_rate', hit_rate || 0, source: 'metrics_collection_job') if hit_rate
    end
  end

  # Clean up old metrics (keep only last 30 days)
  # @return [Integer] - number of metrics deleted
  def self.cleanup_old_metrics
    cutoff_date = 30.days.ago
    deleted = Metric.where("recorded_at < ?", cutoff_date).delete_all
    track_counter('metrics_cleanup_deleted_count', deleted, source: 'metrics_cleanup_job')
    deleted
  rescue StandardError => e
    Rails.logger.error("MetricsTracker: Error cleaning up old metrics: #{e.message}")
    0
  end

  private

  # Log metric tracking errors without blocking user operations
  # @param metric_name [String] - name of the metric
  # @param operation [String] - type of operation (counter, gauge, timing, query, etc.)
  # @param error [StandardError] - the error that occurred
  def self.log_metric_error(metric_name, operation, error)
    Rails.logger.warn("MetricsTracker: Failed to #{operation} '#{metric_name}': #{error.message}")
  end
end
