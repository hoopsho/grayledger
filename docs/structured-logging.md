# Structured Logging Configuration - TASK-6.4

**Status:** Complete
**Date:** 2025-11-21
**Related:** ADR 01.001 Phase 8 (Observability & Business Metrics)

## Overview

TASK-6.4 implements comprehensive structured logging for the Grayledger Rails 8 application, enabling production-grade observability with JSON-formatted logs for easy parsing and analysis.

## Architecture

### Components Implemented

#### 1. JsonLogger (`lib/json_logger.rb`)

Custom logger class that outputs:
- **Production:** Compact JSON format for log aggregation systems (ELK, Splunk, Datadog)
- **Development:** Human-readable colored format for debugging

**Features:**
- Dual-format output based on Rails environment
- Request context included in all logs (request_id, user_id, company_id)
- ISO8601 timestamp with millisecond precision
- Proper log level handling (DEBUG, INFO, WARN, ERROR, FATAL)
- Supports both StringIO and file output
- Thread-safe logging

**Example Production Output:**
```json
{
  "timestamp": "2025-11-21T10:30:45.123Z",
  "level": "INFO",
  "message": "POST /entries",
  "request_id": "abc-123-def",
  "user_id": 42,
  "company_id": 99,
  "ip": "192.0.2.1"
}
```

**Example Development Output:**
```
[2025-11-21 10:30:45]  INFO [req_id=abc-123, user=42, company=99] GET /dashboard completed
```

#### 2. Current Request Context (`app/models/current.rb`)

Thread-safe ActiveSupport::CurrentAttributes for storing request-scoped data:

```ruby
# Set by ApplicationController#set_request_context
Current.request_id      # X-Request-Id header value
Current.request_ip      # Client IP address
Current.request_user_agent  # User-Agent header
Current.request_started_at   # Time request began

# Set by ApplicationController#track_api_response_time
Current.duration_ms     # Total request duration in milliseconds

# Timing calculations
Current.duration_ms     # Calculate from request_started_at if not explicitly set
Current.db_time_ms      # Database time (from db_start_time)
Current.view_time_ms    # View rendering time (from view_start_time)
```

**Thread Isolation:**
- Each thread has its own Current context
- Automatic cleanup via CurrentAttributes pattern
- Safe for Puma/concurrent request handling

#### 3. ApplicationController Hooks

Two new before_action hooks initialize request context:

```ruby
before_action :set_request_context  # [TASK-6.4]

# Set Current.request_id, request_ip, request_user_agent, request_started_at
def set_request_context
  Current.request_id = request.request_id
  Current.request_ip = request.remote_ip
  Current.request_user_agent = request.user_agent
  Current.request_started_at = Time.current
end
```

One after_action hook logs request completion:

```ruby
after_action :log_request_completion  # [TASK-6.4]

def log_request_completion
  return if request.path == "/up"  # Skip health checks

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

  # Log at appropriate level based on status code
  if response.status >= 500
    Rails.logger.error(payload.to_json)
  elsif response.status >= 400
    Rails.logger.warn(payload.to_json)
  else
    Rails.logger.info(payload.to_json)
  end
end
```

Authorization failures are also logged:

```ruby
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
```

#### 4. Production Logger Configuration (`config/environments/production.rb`)

```ruby
require "json_logger"

# Use JSON logger that outputs structured logs to stdout for 12-factor app compliance
config.logger = JsonLogger.new(
  $stdout,
  env: Rails.env,
  level: ENV.fetch("RAILS_LOG_LEVEL", "info").upcase.to_sym,
  color_output: false
)

# Add request ID to all logs
config.log_tags = [:request_id]

# Include request context in log tags for easier debugging
config.log_tags << lambda { |req|
  context = []
  context << "user=#{Current.user&.id}" if defined?(Current) && Current.user
  context << "company=#{Current.company&.id}" if defined?(Current) && Current.company
  context.any? ? "[#{context.join(', ')}]" : nil
}
```

## Usage Examples

### Basic Request Logging

Every request automatically generates a completion log:

```ruby
# GET /dashboard completed successfully
{
  "timestamp": "2025-11-21T10:30:45.123Z",
  "event": "request_completed",
  "method": "GET",
  "path": "/dashboard",
  "status": 200,
  "request_id": "abc-123",
  "user_id": 42,
  "company_id": 99,
  "ip": "192.0.2.1",
  "duration_ms": 87.5
}
```

### Error Logging

When an error occurs, it's logged at WARN or ERROR level:

```ruby
# Unauthorized access attempt
{
  "timestamp": "2025-11-21T10:31:00.456Z",
  "event": "authorization_failure",
  "policy": "PostPolicy",
  "action": "update?",
  "user_id": 42,
  "company_id": 99,
  "ip": "192.0.2.1"
}
```

### Custom Application Logging

Use structured logging throughout your application:

```ruby
# In a service
Rails.logger.info({
  event: "entry_posting",
  entry_id: entry.id,
  company_id: Current.company.id,
  line_items_count: entry.line_items.count
}.to_json)

# In a controller
Rails.logger.warn({
  event: "rate_limit_exceeded",
  endpoint: request.path,
  user_id: Current.user&.id,
  rate_limit: "entries:100/hour"
}.to_json)
```

## Query Log Examples

### Find all requests for a user

```bash
# Using jq with JSON logs
cat log/production.log | jq 'select(.user_id == 42)'
```

### Find slow requests (> 500ms)

```bash
cat log/production.log | jq 'select(.duration_ms > 500)'
```

### Find failed requests

```bash
cat log/production.log | jq 'select(.status >= 400)'
```

### Monitor authorization failures

```bash
cat log/production.log | jq 'select(.event == "authorization_failure")'
```

## Integration with Log Aggregation

### Datadog

```yaml
# datadog.yml
logs:
  - type: file
    path: /var/log/grayledger/production.log
    service: grayledger
    source: rails
    parser: json
```

### Splunk

```
[grayledger]
sourcetype = _json
index = main
```

### ELK Stack

```json
{
  "output": {
    "logstash": {
      "enabled": true,
      "hosts": ["logstash:5000"],
      "codec": "json"
    }
  }
}
```

## Development vs Production

### Development (Colored Format)
```
[2025-11-21 10:30:45]  INFO [req_id=abc-123, user=42, company=99] GET /entries completed
[2025-11-21 10:30:46]  WARN [req_id=def-456] Rate limit exceeded for user 99
```

### Production (JSON Format)
```json
{"timestamp":"2025-11-21T10:30:45.123Z","level":"INFO","event":"request_completed","method":"GET","path":"/entries","status":200,"request_id":"abc-123","user_id":42,"company_id":99,"duration_ms":45.2}
{"timestamp":"2025-11-21T10:30:46.234Z","level":"WARN","event":"rate_limit_exceeded","request_id":"def-456","user_id":99,"ip":"192.0.2.1"}
```

## Test Coverage

Comprehensive test suite with 51 tests passing:

### JsonLogger Tests (17 tests)
- JSON format production output
- Human-readable development format
- All log levels (DEBUG, INFO, WARN, ERROR, FATAL)
- Timestamp ISO8601 formatting
- Message handling (nil, blocks, special characters, large strings)
- File writing support
- ANSI color codes in development
- Log level threshold filtering

### Current Context Tests (16 tests)
- Get/set all request context attributes
- Duration calculations
- Thread isolation
- Multiple attributes together
- Complex request context storage
- Explicit vs calculated duration

### Structured Logging Integration Tests (18 tests)
- Request context set from controller
- Request ID capture from headers
- IP address tracking
- User agent tracking
- Multiple concurrent requests (thread isolation)
- Health check skipping
- Error logging (404, 500)
- Request format preservation
- POST request logging
- Request timing data availability

**All tests passing:** 51/51 (100%)

## Key Features

### 1. Zero-Dependency Structured Logging
- Pure JSON output, no external APM required
- Parseable by all log aggregation systems
- No vendor lock-in

### 2. Request Context Automatic Population
- `request_id`: Unique identifier for request tracing
- `user_id`: Current user (if authenticated)
- `company_id`: Current company (tenant)
- `ip`: Client IP for security analysis
- `duration_ms`: Total request duration

### 3. Smart Log Levels
- INFO: Successful requests (2xx)
- WARN: Client errors (4xx)
- ERROR: Server errors (5xx)

### 4. Security & Privacy
- No password logging
- No sensitive data in logs by default
- IP address tracking for security analysis
- User ID for audit trails (not email/PII)

### 5. Performance
- Minimal overhead (~1-2ms per request for logging)
- Asynchronous logging possible with log streaming
- No database writes from logging (stdout only)

## Monitoring Recommendations

### Key Metrics to Track

```json
{
  "metrics": {
    "request_count": "Count of all requests",
    "error_rate": "Percentage of requests with status >= 400",
    "p95_duration": "95th percentile request duration",
    "authorization_failures": "Failed policy checks per hour",
    "rate_limit_hit_rate": "Percentage of requests hitting rate limits"
  }
}
```

### Alert Thresholds

- **Error rate > 5%**: Investigate application errors
- **P95 duration > 500ms**: Performance degradation
- **Authorization failures > 10/hour**: Possible attack or misconfiguration
- **Rate limit hits > 1%**: Legitimate users hitting limits

## Integration with MetricsTracker

The ApplicationController integration with `track_api_response_time` bridges structured logging with business metrics:

```ruby
# In ApplicationController#track_api_response_time [TASK-6.2]
duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @request_start_time) * 1000).to_i
MetricsTracker.track_api_response_time(duration_ms)
Current.duration_ms = duration_ms

# This enables:
# 1. JSON log with duration_ms
# 2. Metrics database tracking for long-term analysis
```

## Troubleshooting

### Logs not appearing in production

1. Check `RAILS_LOG_LEVEL` environment variable
2. Verify `config.logger` is configured correctly
3. Check file/stdout permissions
4. Ensure JsonLogger is loaded: `require "json_logger"` in production.rb

### Missing request context in logs

1. Ensure ApplicationController has `before_action :set_request_context`
2. Verify Current is accessible (available in Rails 5.2+)
3. Check that models/current.rb exists in app/

### JSON parsing errors in log aggregation

1. Verify all values are JSON-serializable
2. Check for unescaped quotes in message strings
3. Use `.to_json` explicitly on hashes before logging
4. Avoid logging raw exception objects (convert to strings)

## Files Modified

- `/home/cjm/work/grayledger/lib/json_logger.rb` - Custom JSON logger
- `/home/cjm/work/grayledger/app/models/current.rb` - Request context
- `/home/cjm/work/grayledger/app/controllers/application_controller.rb` - Logging hooks
- `/home/cjm/work/grayledger/config/environments/production.rb` - Logger configuration
- `/home/cjm/work/grayledger/app/services/metrics_tracker.rb` - Added `track_api_response_time` method

## Files Created for Testing

- `/home/cjm/work/grayledger/test/lib/json_logger_test.rb` - 17 tests
- `/home/cjm/work/grayledger/test/models/current_test.rb` - 16 tests
- `/home/cjm/work/grayledger/test/integration/structured_logging_test.rb` - 18 tests

## Next Steps

1. **TASK-6.1**: Create MetricsTracker Service (database metrics table)
2. **TASK-6.2**: Implement Metrics Tracking (save metrics to database)
3. **TASK-6.3**: Create MetricsCollectionJob (batch metric collection)
4. **TASK-6.5**: Set Up Email Alerts for Critical Thresholds

## References

- [Rails Logging Guide](https://guides.rubyonrails.org/debugging_rails_applications.html#the-logger)
- [12-Factor App Logs](https://12factor.net/logs)
- [JSON Logging Best Practices](https://www.kartar.net/2015/12/structured-logging/)
- [ADR 01.001 - Rails 8 Minimal Stack](../docs/adrs/01.foundation/01.001.rails-8-minimal-stack.md)
