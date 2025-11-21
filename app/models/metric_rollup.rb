# app/models/metric_rollup.rb
#
# Stores aggregated and summarized metrics over time.
# Used for historical analysis, trends, and reporting.
#
# Rollup intervals:
# - hourly: Summary of metrics for each hour
# - daily: Summary of metrics for each day
# - weekly: Summary of metrics for each week
#
# Statistics stored as JSON:
# - Counters: {sum, count}
# - Gauges: {avg, min, max, latest}
# - Histograms: {sum, avg, min, max, count, p50, p95, p99}
#
class MetricRollup < ApplicationRecord
  # Validations
  validates :metric_name, :metric_type, :rollup_interval, :aggregated_at, presence: true
  validates :metric_type, inclusion: {in: %w[counter gauge histogram]}
  validates :rollup_interval, inclusion: {in: %w[hourly daily weekly]}
  validates :statistics, presence: true
  validates :sample_count, numericality: {greater_than_or_equal_to: 0}

  # Scopes for common queries
  scope :recent, -> { order(aggregated_at: :desc) }
  scope :by_metric, ->(name) { where(metric_name: name) }
  scope :by_type, ->(type) { where(metric_type: type) }
  scope :by_interval, ->(interval) { where(rollup_interval: interval) }
  scope :since, ->(time) { where("aggregated_at >= ?", time) }
  scope :until, ->(time) { where("aggregated_at <= ?", time) }
  scope :for_period, ->(start_time, end_time) { since(start_time).until(end_time) }

  # Get rollups for a specific metric across all intervals
  scope :for_metric, ->(metric_name) { where(metric_name: metric_name).order(aggregated_at: :desc) }

  # Get hourly rollups for the last N hours
  scope :hourly_since, ->(time) { by_interval("hourly").since(time) }

  # Get daily rollups for the last N days
  scope :daily_since, ->(time) { by_interval("daily").since(time) }

  # Get weekly rollups for the last N weeks
  scope :weekly_since, ->(time) { by_interval("weekly").since(time) }

  # Cleanup old rollups
  scope :older_than, ->(time) { where("aggregated_at < ?", time) }

  # Get the latest rollup for a specific metric and interval
  def self.latest_for(metric_name, interval = "hourly")
    by_metric(metric_name).by_interval(interval).recent.first
  end

  # Get trend data for a metric over time
  def self.trend_for(metric_name, interval = "daily", lookback_days = 30)
    end_time = Time.current
    start_time = end_time - lookback_days.days
    by_metric(metric_name).by_interval(interval).for_period(start_time, end_time).order(aggregated_at: :asc)
  end

  # Get latest values for all metrics
  def self.latest_all
    group_by(&:metric_name).transform_values do |rollups|
      rollups.sort_by(&:aggregated_at).last
    end
  end

  # Cleanup old raw metrics (keep only 7 days)
  def self.cleanup_old_metrics(days_to_keep = 7)
    cutoff_time = Time.current - days_to_keep.days
    deleted_count = older_than(cutoff_time).delete_all
    Rails.logger.info("Cleaned up #{deleted_count} metric rollups older than #{days_to_keep} days")
    deleted_count
  end

  # Get average of a statistic across recent rollups
  # @param metric_name [String] - name of metric
  # @param statistic [String] - name of statistic (avg, p95, sum, etc)
  # @param interval [String] - hourly, daily, weekly
  # @param lookback [Integer] - how many periods to average
  def self.average_statistic(metric_name, statistic, interval = "hourly", lookback = 24)
    rollups = by_metric(metric_name).by_interval(interval).recent.limit(lookback)
    return nil if rollups.empty?

    values = rollups.map { |r| r.statistics[statistic] }.compact
    return nil if values.empty?

    (values.sum / values.length).round(2)
  end

  # Check if metric value exceeds threshold
  def exceeds_threshold?(threshold)
    value = statistics["max"] || statistics["avg"] || statistics["sum"] || statistics["latest"]
    value.present? && value > threshold
  end

  # Check if metric value is below threshold
  def below_threshold?(threshold)
    value = statistics["avg"] || statistics["latest"]
    value.present? && value < threshold
  end

  # Get human-readable summary of statistics
  def summary
    case metric_type
    when "counter"
      "Total: #{statistics['sum']}, Count: #{statistics['count']}"
    when "gauge"
      "Avg: #{statistics['avg']}, Min: #{statistics['min']}, Max: #{statistics['max']}, Latest: #{statistics['latest']}"
    when "histogram"
      "Avg: #{statistics['avg']}, p95: #{statistics['p95']}, p99: #{statistics['p99']}, Count: #{statistics['count']}"
    else
      statistics.to_s
    end
  end

  # Calculate percentage change from previous rollup
  def percent_change_from_previous
    # Find previous rollup for same metric and interval
    previous = MetricRollup
      .where(metric_name: metric_name, metric_type: metric_type, rollup_interval: rollup_interval)
      .where("aggregated_at < ?", aggregated_at)
      .order(aggregated_at: :desc)
      .first

    return nil unless previous.present?

    # Get comparable values based on metric type
    current_val = extract_comparable_value
    previous_val = previous.extract_comparable_value

    return nil if previous_val.zero?

    (((current_val.to_f - previous_val.to_f) / previous_val.to_f.abs) * 100).round(2)
  end

  # Extract the most appropriate value for comparison
  def extract_comparable_value
    case metric_type
    when "counter"
      statistics["sum"] || 0
    when "gauge"
      statistics["avg"] || statistics["latest"] || 0
    when "histogram"
      statistics["mean"] || statistics["avg"] || statistics["sum"] || 0
    else
      0
    end
  end
end
