require "json"

# Structured JSON logging formatter for Rails
# Outputs logs in JSON format for easy parsing in production monitoring systems
#
# Example output:
# {"timestamp":"2025-11-21T10:30:45.123Z","level":"INFO","message":"POST /entries","request_id":"abc123","user_id":1,"company_id":42,"ip":"192.0.2.1","status":201,"duration_ms":45.2}
class JsonLogger
  # ANSI color codes for development logging
  COLORS = {
    DEBUG: "\e[36m",      # Cyan
    INFO: "\e[32m",       # Green
    WARN: "\e[33m",       # Yellow
    ERROR: "\e[31m",      # Red
    FATAL: "\e[35m"       # Magenta
  }.freeze
  RESET = "\e[0m"

  # Logger level constants
  LEVEL_NAMES = {
    Logger::DEBUG => "DEBUG",
    Logger::INFO => "INFO",
    Logger::WARN => "WARN",
    Logger::ERROR => "ERROR",
    Logger::FATAL => "FATAL"
  }.freeze

  def initialize(logdev, **options)
    @logdev = logdev
    @formatter = options[:formatter] || method(:default_formatter)
    @level = options[:level] || Logger::INFO
    @env = options[:env] || Rails.env
    @color_output = options[:color_output].nil? ? !Rails.env.production? : options[:color_output]
  end

  def add(severity, message = nil, progname = nil, &block)
    return true if severity < @level

    message = block.call if message.nil? && block_given?
    formatted = format_entry(severity, Time.current, progname, message)

    if @logdev.is_a?(String)
      File.open(@logdev, "a") { |f| f.write("#{formatted}\n") }
    else
      @logdev.write("#{formatted}\n") if @logdev.respond_to?(:write)
    end

    true
  end

  private

  # Format log entry based on environment
  def format_entry(severity, time, progname, message)
    case @env
    when "production"
      format_json(severity, time, message)
    else
      format_colored(severity, time, message)
    end
  end

  # Production format: compact JSON for log aggregation systems
  def format_json(severity, time, message)
    level_name = LEVEL_NAMES[severity] || "UNKNOWN"
    payload = {
      timestamp: time.iso8601(3),
      level: level_name,
      message: message.to_s
    }

    # Include request context if available via Current
    if defined?(Current) && Current.respond_to?(:request_id)
      payload[:request_id] = Current.request_id if Current.request_id
      payload[:user_id] = Current.user&.id if Current.user
      payload[:company_id] = Current.company&.id if Current.company
    end

    JSON.generate(payload)
  end

  # Development format: colored, human-readable
  def format_colored(severity, time, message)
    level_name = LEVEL_NAMES[severity] || "UNKNOWN"
    color = @color_output ? (COLORS[level_name.to_sym] || "") : ""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    level_str = level_name.rjust(5)

    request_context = ""
    if defined?(Current) && Current.respond_to?(:request_id)
      parts = []
      parts << "req_id=#{Current.request_id}" if Current.request_id
      parts << "user=#{Current.user&.id}" if Current.user
      parts << "company=#{Current.company&.id}" if Current.company
      request_context = " [#{parts.join(', ')}]" if parts.any?
    end

    "#{color}[#{timestamp}] #{level_str}#{RESET}#{request_context} #{message}"
  end

  def default_formatter(severity, time, progname, message)
    "#{time} #{severity}: #{message}\n"
  end
end
