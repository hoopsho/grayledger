# Metric tracks business-critical metrics using PostgreSQL storage
# Supports counter (increment), gauge (current value), and timing (duration) metric types
#
# Thread-safe atomic operations leverage database-level constraints and indexes
#
# Examples:
#   # Track daily active users (counter)
#   Metric.track_counter('daily_active_users', 1, company_id: 123)
#   Metric.count_by_day('daily_active_users', tags: { company_id: 123 })
#
#   # Track cache hit rate (gauge)
#   Metric.track_gauge('cache_hit_rate', 0.95, service: 'solid_cache')
#   Metric.find_latest('cache_hit_rate')
#
#   # Track request duration (timing)
#   Metric.track_timing('request_duration_ms', 125, endpoint: '/api/entries')
#   Metric.percentile('request_duration_ms', 95)

class Metric < ApplicationRecord
  # Validations
  validates :metric_name, presence: true, uniqueness: { scope: [:metric_type, :recorded_at], message: "already tracked for this type at this time" }
  validates :metric_type, presence: true, inclusion: { in: %w(counter gauge timing), message: "must be 'counter', 'gauge', or 'timing'" }
  validates :value, presence: true, numericality: true
  validates :recorded_at, presence: true
  # Tags can be empty hash (default) or contain filtering metadata
  # Tags are stored as JSONB, defaulting to empty hash when not specified

  # Scopes for querying metrics
  scope :by_name, ->(name) { where(metric_name: name) }
  scope :by_type, ->(type) { where(metric_type: type) }
  scope :in_time_range, ->(start_time, end_time) { where(recorded_at: start_time..end_time) }
  scope :after, ->(time) { where("recorded_at > ?", time) }
  scope :before, ->(time) { where("recorded_at < ?", time) }
  scope :by_tag, ->(tag_name, tag_value) { where("tags->? = ?", tag_name, tag_value.to_json) }
  scope :today, -> { in_time_range(Date.current.beginning_of_day, Date.current.end_of_day) }
  scope :this_week, -> { in_time_range(Date.current.beginning_of_week, Date.current.end_of_week) }
  scope :this_month, -> { in_time_range(Date.current.beginning_of_month, Date.current.end_of_month) }

  # Return counters: all counter-type metrics grouped by metric_name and date
  # Returns { 'metric_name' => { date => count, ... }, ... }
  scope :counters, -> { by_type('counter') }

  # Return gauges: all gauge-type metrics grouped by metric_name
  scope :gauges, -> { by_type('gauge') }

  # Return timings: all timing-type metrics grouped by metric_name
  scope :timings, -> { by_type('timing') }

  # Class methods for tracking metrics

  # Track a counter (increment-only metric)
  # @param metric_name [String] - name of the metric (e.g., "entries_created")
  # @param value [Numeric] - amount to increment (default: 1)
  # @param tags [Hash] - optional tags for filtering (e.g., company_id: 1)
  # @return [Metric] - created or updated metric record
  def self.track_counter(metric_name, value = 1, tags = {})
    record_metric(metric_name, 'counter', value, tags)
  end

  # Track a gauge (current value metric)
  # @param metric_name [String] - name of the metric (e.g., "cache_hit_rate")
  # @param value [Numeric] - current gauge value
  # @param tags [Hash] - optional tags for filtering
  # @return [Metric] - created metric record
  def self.track_gauge(metric_name, value, tags = {})
    record_metric(metric_name, 'gauge', value, tags)
  end

  # Track a timing (duration metric in milliseconds)
  # @param metric_name [String] - name of the metric (e.g., "request_duration_ms")
  # @param duration_ms [Numeric] - duration in milliseconds
  # @param tags [Hash] - optional tags for filtering
  # @return [Metric] - created metric record
  def self.track_timing(metric_name, duration_ms, tags = {})
    record_metric(metric_name, 'timing', duration_ms, tags)
  end

  # Measure execution time of a block and track as timing metric
  # @param metric_name [String] - name of the metric
  # @param tags [Hash] - optional tags
  # @return [Object] - return value of the block
  #
  # Example:
  #   result = Metric.measure_timing('expensive_operation') do
  #     ExpensiveCalculation.perform
  #   end
  def self.measure_timing(metric_name, tags = {}, &block)
    start_time = Time.current
    result = block.call
  ensure
    duration_ms = ((Time.current - start_time) * 1000).round(2)
    track_timing(metric_name, duration_ms, tags)
    result
  end

  # Get the most recent metric value for a given metric name
  # @param metric_name [String] - name of the metric
  # @param tags [Hash] - optional tags to filter by
  # @return [Metric, nil] - most recent metric or nil
  def self.get_metric(metric_name, tags = {})
    query = by_name(metric_name)
    query = apply_tag_filter(query, tags)
    query.order(recorded_at: :desc).first
  end

  # Get all metrics for a given name in a time range
  # @param metric_name [String] - name of the metric
  # @param start_time [DateTime] - start of time range
  # @param end_time [DateTime] - end of time range (default: now)
  # @param tags [Hash] - optional tags to filter by
  # @return [ActiveRecord::Relation] - matching metrics
  def self.get_metrics_in_range(metric_name, start_time, end_time = Time.current, tags = {})
    query = by_name(metric_name).in_time_range(start_time, end_time)
    apply_tag_filter(query, tags)
  end

  # Aggregations (requires ActiveRecord calculations)

  # Sum all values for a metric (useful for counters)
  # @param metric_name [String] - name of the metric
  # @param start_time [DateTime] - optional start time
  # @param end_time [DateTime] - optional end time
  # @param tags [Hash] - optional tags to filter by
  # @return [Numeric] - sum of all metric values
  def self.sum_values(metric_name, start_time = nil, end_time = nil, tags = {})
    query = by_name(metric_name)
    query = query.in_time_range(start_time, end_time) if start_time && end_time
    query = apply_tag_filter(query, tags)
    query.sum(:value).to_f
  end

  # Average value for a metric (useful for gauges and timings)
  # @param metric_name [String] - name of the metric
  # @param start_time [DateTime] - optional start time
  # @param end_time [DateTime] - optional end time
  # @param tags [Hash] - optional tags to filter by
  # @return [Float] - average of all metric values
  def self.avg_values(metric_name, start_time = nil, end_time = nil, tags = {})
    query = by_name(metric_name)
    query = query.in_time_range(start_time, end_time) if start_time && end_time
    query = apply_tag_filter(query, tags)
    query.average(:value)&.to_f || 0.0
  end

  # Minimum value for a metric
  # @param metric_name [String] - name of the metric
  # @param start_time [DateTime] - optional start time
  # @param end_time [DateTime] - optional end time
  # @param tags [Hash] - optional tags to filter by
  # @return [Numeric] - minimum metric value
  def self.min_values(metric_name, start_time = nil, end_time = nil, tags = {})
    query = by_name(metric_name)
    query = query.in_time_range(start_time, end_time) if start_time && end_time
    query = apply_tag_filter(query, tags)
    query.minimum(:value)
  end

  # Maximum value for a metric
  # @param metric_name [String] - name of the metric
  # @param start_time [DateTime] - optional start time
  # @param end_time [DateTime] - optional end time
  # @param tags [Hash] - optional tags to filter by
  # @return [Numeric] - maximum metric value
  def self.max_values(metric_name, start_time = nil, end_time = nil, tags = {})
    query = by_name(metric_name)
    query = query.in_time_range(start_time, end_time) if start_time && end_time
    query = apply_tag_filter(query, tags)
    query.maximum(:value)
  end

  # Calculate percentile for a metric (useful for latency percentiles)
  # @param metric_name [String] - name of the metric
  # @param percentile [Integer] - percentile to calculate (1-100)
  # @param start_time [DateTime] - optional start time
  # @param end_time [DateTime] - optional end time
  # @param tags [Hash] - optional tags to filter by
  # @return [Numeric] - value at the given percentile
  #
  # Example:
  #   p95_latency = Metric.percentile('request_duration_ms', 95, 1.hour.ago)
  def self.percentile(metric_name, percentile = 50, start_time = nil, end_time = nil, tags = {})
    query = by_name(metric_name)
    query = query.in_time_range(start_time, end_time) if start_time && end_time
    query = apply_tag_filter(query, tags)

    # Use Postgres PERCENTILE_CONT for continuous percentile calculation
    result = query.pluck("PERCENTILE_CONT(#{percentile.to_f / 100}) WITHIN GROUP (ORDER BY value)").first
    result&.to_f
  end

  # Count metrics by day (useful for daily active users, entries created, etc.)
  # @param metric_name [String] - name of the metric
  # @param start_date [Date] - optional start date
  # @param end_date [Date] - optional end date (default: today)
  # @param tags [Hash] - optional tags to filter by
  # @return [Hash] - { date => count, ... }
  def self.count_by_day(metric_name, start_date = nil, end_date = nil, tags = {})
    query = by_name(metric_name)

    if start_date && end_date
      query = query.in_time_range(start_date.beginning_of_day, end_date.end_of_day)
    elsif start_date
      query = query.in_time_range(start_date.beginning_of_day, Date.current.end_of_day)
    end

    query = apply_tag_filter(query, tags)

    # Group by date and count
    query.group("DATE(recorded_at)").count.transform_keys { |k| k.to_date }
  end

  # Sum metrics by day (useful for daily counter totals)
  # @param metric_name [String] - name of the metric
  # @param start_date [Date] - optional start date
  # @param end_date [Date] - optional end date (default: today)
  # @param tags [Hash] - optional tags to filter by
  # @return [Hash] - { date => sum, ... }
  def self.sum_by_day(metric_name, start_date = nil, end_date = nil, tags = {})
    query = by_name(metric_name)

    if start_date && end_date
      query = query.in_time_range(start_date.beginning_of_day, end_date.end_of_day)
    elsif start_date
      query = query.in_time_range(start_date.beginning_of_day, Date.current.end_of_day)
    end

    query = apply_tag_filter(query, tags)

    # Group by date and sum values
    query.group("DATE(recorded_at)").sum(:value).transform_keys { |k| k.to_date }
  end

  private

  # Record a metric in the database (thread-safe using database constraints)
  # @param metric_name [String] - name of the metric
  # @param metric_type [String] - type of metric ('counter', 'gauge', 'timing')
  # @param value [Numeric] - metric value
  # @param tags [Hash] - optional tags for filtering (default: {})
  # @return [Metric] - created metric record
  def self.record_metric(metric_name, metric_type, value, tags = {})
    # Ensure tags is always a hash (even if empty)
    tags = {} if tags.nil? || !tags.is_a?(Hash)

    Metric.create!(
      metric_name: metric_name,
      metric_type: metric_type,
      value: value,
      tags: tags,
      recorded_at: Time.current
    )
  end

  # Helper to apply tag filters to a query
  # @param query [ActiveRecord::Relation] - base query
  # @param tags [Hash] - tags to filter by
  # @return [ActiveRecord::Relation] - filtered query
  def self.apply_tag_filter(query, tags)
    tags.each do |key, value|
      # Convert symbol keys to strings to match stored JSONB format
      tag_key = key.is_a?(Symbol) ? key.to_s : key
      query = query.by_tag(tag_key, value)
    end
    query
  end
end