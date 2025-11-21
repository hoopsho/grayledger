class Alert < ApplicationRecord
  # Alert types for critical threshold monitoring
  ALERT_TYPES = {
    error_rate: "error_rate",
    cache_hit_rate: "cache_hit_rate",
    job_failures: "job_failures"
  }.freeze

  # Validation
  validates :alert_type, presence: true, inclusion: {in: ALERT_TYPES.values}
  validates :metric_name, presence: true
  validates :current_value, :threshold, presence: true, numericality: true
  validates :triggered_at, presence: true
  validate :triggered_at_cannot_be_in_future
  validate :resolved_at_after_triggered_at

  # Scopes for querying
  scope :active, -> { where(resolved_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }
  scope :by_type, ->(type) { where(alert_type: type) }
  scope :by_metric, ->(metric) { where(metric_name: metric) }
  scope :recent, -> { order(triggered_at: :desc) }
  scope :unresolved_since, ->(time) { active.where("triggered_at >= ?", time) }

  # Mark an alert as resolved
  def resolve!
    update(resolved_at: Time.current)
  end

  # Check if alert is currently active (unresolved)
  def active?
    resolved_at.nil?
  end

  # Duration the alert has been active
  def duration
    end_time = resolved_at || Time.current
    end_time - triggered_at
  end

  # Check if alert can be rate-limited (no recent alert of same type)
  def self.rate_limit_exceeded?(alert_type, metric_name, window = 1.hour)
    active.by_type(alert_type).by_metric(metric_name)
           .where("triggered_at > ?", Time.current - window).exists?
  end

  # Create or resolve alert based on threshold
  def self.check_threshold(alert_type, metric_name, current_value, threshold, description = nil)
    threshold_exceeded = case alert_type
                         when ALERT_TYPES[:error_rate]
                           current_value > threshold
                         when ALERT_TYPES[:cache_hit_rate]
                           current_value < threshold
                         when ALERT_TYPES[:job_failures]
                           current_value > threshold
                         else
                           false
                         end

    if threshold_exceeded
      # Trigger alert if not rate-limited
      unless rate_limit_exceeded?(alert_type, metric_name)
        Alert.create!(
          alert_type: alert_type,
          metric_name: metric_name,
          current_value: current_value,
          threshold: threshold,
          triggered_at: Time.current,
          description: description
        )
      end
    else
      # Resolve active alerts if threshold is met
      active.by_type(alert_type).by_metric(metric_name).each(&:resolve!)
    end
  end

  private

  def triggered_at_cannot_be_in_future
    if triggered_at.present? && triggered_at > Time.current
      errors.add(:triggered_at, "cannot be in the future")
    end
  end

  def resolved_at_after_triggered_at
    if resolved_at.present? && triggered_at.present? && resolved_at < triggered_at
      errors.add(:resolved_at, "must be after triggered_at")
    end
  end
end
