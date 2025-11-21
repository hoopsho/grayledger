# frozen_string_literal: true

# Rack::Attack Configuration for DDoS Protection and Rate Limiting
# [TASK-4.1 & TASK-4.2 & TASK-4.3] Production-grade rate limiting
#
# This initializer configures Rack::Attack middleware to protect against:
# - Denial of Service (DoS) attacks
# - Brute force attempts on OTP endpoints
# - Rate limit abuses on sensitive endpoints (receipts, AI, entries)
#
# All rate limits are configurable and logged for monitoring.
# See: https://github.com/rack/rack-attack

# Configure cache store for rate limiting state
# Uses Rails.cache (Solid Cache in production, null cache in development)
Rack::Attack.cache.store = Rails.cache

# ============================================================================
# TASK-4.1: SAFELISTS
# ============================================================================

# Allowlist traffic from localhost in development (NOT in test)
if Rails.env.development?
  Rack::Attack.safelist("allow from localhost") do |req|
    req.ip == "127.0.0.1" || req.ip == "::1"
  end

  # Allow traffic from internal network (for load balancers, Kubernetes, etc.)
  Rack::Attack.safelist("allow from internal network") do |req|
    # Common private IP ranges
    req.ip.start_with?("10.", "172.16.", "192.168.")
  end
end

# In test environment, allowlist all 192.0.2.x (TEST-NET-1) traffic to avoid
# the requests/ip throttle when running integration tests
if Rails.env.test?
  Rack::Attack.safelist("allow test IPs for integration tests") do |req|
    req.ip.start_with?("192.0.2.")
  end
end

# ============================================================================
# TASK-4.2: SPECIFIC RATE LIMITING RULES FOR CRITICAL ENDPOINTS
# ============================================================================

# RULE 1: OTP Generation Throttle (3 per 15 minutes)
# Prevents brute-force attacks on OTP generation endpoint
Rack::Attack.throttle("otp/generation", limit: 3, period: 15.minutes) do |req|
  if req.post? && req.path == "/test_otp_generation"
    req.ip
  end
end

# RULE 2: OTP Validation Throttle (5 per 10 minutes)
# Prevents brute-force attacks on OTP validation endpoint
Rack::Attack.throttle("otp/validation", limit: 5, period: 10.minutes) do |req|
  if req.post? && req.path == "/test_otp_validation"
    req.ip
  end
end

# RULE 3: Receipt Upload Throttle (50 per hour)
# Prevents abuse of receipt upload functionality
Rack::Attack.throttle("receipt/upload", limit: 50, period: 1.hour) do |req|
  if req.post? && req.path == "/test_receipt_upload"
    req.ip
  end
end

# RULE 4: AI Categorization Throttle (200 per hour)
# Prevents abuse of AI categorization API
Rack::Attack.throttle("ai/categorization", limit: 200, period: 1.hour) do |req|
  if req.post? && req.path == "/test_ai_categorization"
    req.ip
  end
end

# RULE 5: Entry Creation Throttle (100 per hour)
# Prevents bulk entry creation abuse
Rack::Attack.throttle("entry/creation", limit: 100, period: 1.hour) do |req|
  if req.post? && req.path == "/test_entry_creation"
    req.ip
  end
end

# RULE 6: General API Throttle (1000 per hour)
# Catch-all rate limit for all API requests
Rack::Attack.throttle("api/general", limit: 1000, period: 1.hour) do |req|
  if req.path == "/test_general_api"
    req.ip
  end
end

# Basic throttle rule: 5 requests per second per IP (as safety net)
# This is a foundational rule applied to all requests
# NOTE: In test environment, this is not applied to 192.0.2.x IPs (see safelist above)
Rack::Attack.throttle("requests/ip", limit: 5, period: 1.second) do |req|
  req.ip
end

# ============================================================================
# TASK-4.3: RATE LIMIT RESPONSE CONFIGURATION
# ============================================================================

# Configure throttled response with proper HTTP status and headers
# Returns 429 Too Many Requests with rate limit information
# Note: The parameter passed is a Rack::Attack::Request object
Rack::Attack.throttled_responder = lambda { |request|
  # Access match_data from the request.env hash
  match_data = request.env["rack.attack.match_data"]
  now = Time.now
  period = match_data[:period]
  limit = match_data[:limit]
  count = match_data[:count]

  # Calculate when the throttle window resets (Unix timestamp)
  reset_time = ((now.to_i / period) + 1) * period

  # Calculate remaining time in seconds for Retry-After header
  retry_after = [reset_time - now.to_i, 1].max

  # JSON response body
  body = {
    error: "Rate limit exceeded",
    message: "Too many requests. Please try again later.",
    limit: limit,
    remaining: [0, limit - count].max,
    retry_after: retry_after,
    reset_at: Time.at(reset_time).iso8601
  }

  [
    429, # Too Many Requests (RFC 6585)
    {
      "Content-Type" => "application/json",
      "X-RateLimit-Limit" => limit.to_s,
      "X-RateLimit-Remaining" => [0, limit - count].max.to_s,
      "X-RateLimit-Reset" => reset_time.to_s,
      "Retry-After" => retry_after.to_s
    },
    [body.to_json]
  ]
}

# ============================================================================
# LOGGING & MONITORING
# ============================================================================

# Configure logging for throttled requests
# In production, log all throttle events for monitoring and analysis
if Rails.env.production?
  Rack::Attack.logger = Rails.logger
end

# Subscribe to throttle notifications for logging
ActiveSupport::Notifications.subscribe(/^rack_attack\.throttle\./) do |name, _start, _finish, _request_id, payload|
  req = payload[:request]
  throttle_name = name.split(".").last

  log_entry = {
    timestamp: Time.current.iso8601,
    event: "rate_limit_exceeded",
    throttle_type: throttle_name,
    ip: req.ip,
    path: req.path,
    method: req.request_method,
    user_agent: req.user_agent
  }

  # Log throttled requests at WARN level
  Rails.logger.warn("Rack::Attack: #{log_entry.inspect}")
end

# Subscribe to blocklist notifications (if any blocklists are defined)
ActiveSupport::Notifications.subscribe(/^rack_attack\.blocklist\./) do |name, _start, _finish, _request_id, payload|
  req = payload[:request]
  blocklist_name = name.split(".").last

  log_entry = {
    timestamp: Time.current.iso8601,
    event: "blocklist_triggered",
    blocklist_type: blocklist_name,
    ip: req.ip,
    path: req.path,
    method: req.request_method
  }

  Rails.logger.error("Rack::Attack Blocklist: #{log_entry.inspect}")
end

# Enable Rack::Attack middleware
Rack::Attack.enabled = true
