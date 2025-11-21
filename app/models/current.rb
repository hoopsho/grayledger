# Thread-safe request context for storing current user, company, request_id, and timing data
# Used throughout the application to access request-scoped values
#
# Example usage:
#   Current.user = @user
#   Current.company = @company
#   Current.request_id = request.id
#   Current.request_started_at = Time.current
#
# Access in any controller/service:
#   Rails.logger.info("User #{Current.user&.id} posting entry")
#   Rails.cache.write("entry_#{Current.company.id}", entry)
class Current < ActiveSupport::CurrentAttributes
  # User and company for row-level tenancy (ADR 03.001)
  attribute :user
  attribute :company

  # Request context for structured logging
  attribute :request_id
  attribute :request_ip
  attribute :request_user_agent
  attribute :request_started_at

  # Timing data for observability
  attribute :db_start_time
  attribute :view_start_time

  # Store duration_ms as a regular attribute that can be overridden
  class_variable_set(:@@duration_ms_override, {})

  # Calculated timing methods
  def self.duration_ms
    # If duration_ms was explicitly set via assignment, return it
    # Use thread ID as key to support thread isolation
    override = class_variable_get(:@@duration_ms_override)[Thread.current.object_id]
    if override.present?
      override
    elsif request_started_at.present?
      ((Time.current - request_started_at) * 1000).round(2)
    end
  end

  # Override setter to store duration_ms separately
  def self.duration_ms=(value)
    overrides = class_variable_get(:@@duration_ms_override)
    overrides[Thread.current.object_id] = value
    class_variable_set(:@@duration_ms_override, overrides)
  end

  def self.db_time_ms
    db_start_time.present? ? ((Time.current - db_start_time) * 1000).round(2) : nil
  end

  def self.view_time_ms
    view_start_time.present? ? ((Time.current - view_start_time) * 1000).round(2) : nil
  end

  # Override reset to also clear duration_ms overrides for this thread
  def self.reset
    super
    overrides = class_variable_get(:@@duration_ms_override)
    overrides.delete(Thread.current.object_id)
    class_variable_set(:@@duration_ms_override, overrides)
  end
end
