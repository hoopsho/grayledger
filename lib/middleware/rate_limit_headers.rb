# frozen_string_literal: true

module Middleware
  # Middleware to add X-RateLimit-* headers to successful responses
  # This complements Rack::Attack by providing rate limit information
  # even when the request succeeds
  class RateLimitHeaders
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      # Only add headers if rate limit data is available and response is successful
      if env["rack.attack.match_data"] && status < 400
        match_data = env["rack.attack.match_data"]
        limit = match_data[:limit]
        count = match_data[:count]
        period = match_data[:period]
        now = Time.now.to_i

        # Calculate reset time and remaining
        reset_time = ((now / period) + 1) * period
        remaining = [limit - count, 0].max

        headers["X-RateLimit-Limit"] = limit.to_s
        headers["X-RateLimit-Remaining"] = remaining.to_s
        headers["X-RateLimit-Reset"] = reset_time.to_s
      end

      [status, headers, body]
    end
  end
end
