class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Default authorization failure handler for Pundit
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Add rate limit headers to successful responses [TASK-4.3]
  after_action :add_rate_limit_headers

  private

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
end
