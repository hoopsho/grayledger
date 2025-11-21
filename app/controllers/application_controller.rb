class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Set up request context for structured logging [TASK-6.4]
  before_action :set_request_context

  # Track API response times [TASK-6.2]
  before_action :track_api_request_start

  # Default authorization failure handler for Pundit
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Log authorization failures [TASK-6.4]
  rescue_from Pundit::NotAuthorizedError, with: :log_authorization_failure

  # Add rate limit headers to successful responses [TASK-4.3]
  after_action :add_rate_limit_headers

  # Track API response times and metrics [TASK-6.2]
  after_action :track_api_response_time

  # Log request completion with timing [TASK-6.4]
  after_action :log_request_completion

  private

  # Set up Current context with request metadata [TASK-6.4]
  def set_request_context
    Current.request_id = request.request_id
    Current.request_ip = request.remote_ip
    Current.request_user_agent = request.user_agent
    Current.request_started_at = Time.current
  end

  # Track API request start time for performance metrics [TASK-6.2]
  def track_api_request_start
    @request_start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # Track API response time after request completes [TASK-6.2]
  def track_api_response_time
    return unless @request_start_time

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @request_start_time) * 1000).to_i
    MetricsTracker.track_api_response_time(duration_ms)

    # Store duration in Current for logging
    Current.duration_ms = duration_ms
  end

  def user_not_authorized(exception)
    exception.policy.class.to_s.underscore
    exception.query.to_s.sub(/\?$/, "")

    # You can customize this behavior based on your needs
    # For HTML requests, redirect to root; for JSON requests, return 403
    if request.format.json?
      render json: {error: "You are not authorized to perform this action"}, status: :forbidden
    else
      redirect_to root_url, alert: "You are not authorized to perform this action"
    end
  end

  # Log authorization failure to structured logs [TASK-6.4]
  def log_authorization_failure(exception)
    Rails.logger.warn({
      event: "authorization_failure",
      policy: exception.policy.class.name,
      action: exception.query,
      user_id: Current.user&.id,
      company_id: Current.company&.id,
      ip: Current.request_ip
    }.to_json)
  end

  def add_rate_limit_headers
    # Only add headers if rate limit data is available and response is successful
    if request.env["rack.attack.match_data"] && response.status < 400
      match_data = request.env["rack.attack.match_data"]
      limit = match_data[:limit]
      count = match_data[:count]
      period = match_data[:period]
      now = Time.now.to_i

      # Calculate reset time and remaining
      reset_time = ((now / period) + 1) * period
      remaining = [limit - count, 0].max

      response.headers["X-RateLimit-Limit"] = limit.to_s
      response.headers["X-RateLimit-Remaining"] = remaining.to_s
      response.headers["X-RateLimit-Reset"] = reset_time.to_s
    end
  end

  # Log request completion with timing information [TASK-6.4]
  def log_request_completion
    return if request.path == "/up" # Skip health checks

    payload = {
      timestamp: Time.current.iso8601(3),
      event: "request_completed",
      method: request.method,
      path: request.path,
      status: response.status,
      request_id: Current.request_id,
      user_id: Current.user&.id,
      company_id: Current.company&.id,
      ip: Current.request_ip,
      duration_ms: Current.duration_ms
    }

    # Add rate limiting info if available
    if request.env["rack.attack.match_data"]
      payload[:rate_limited] = response.status == 429
    end

    # Log at appropriate level based on status code
    if response.status >= 500
      Rails.logger.error(payload.to_json)
    elsif response.status >= 400
      Rails.logger.warn(payload.to_json)
    else
      Rails.logger.info(payload.to_json)
    end
  end
end
