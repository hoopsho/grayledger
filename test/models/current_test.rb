require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  teardown do
    Current.reset
  end

  test "sets and retrieves request_id" do
    Current.request_id = "abc-123-def-456"
    assert_equal "abc-123-def-456", Current.request_id
  end

  test "sets and retrieves request_ip" do
    Current.request_ip = "192.0.2.1"
    assert_equal "192.0.2.1", Current.request_ip
  end

  test "sets and retrieves request_user_agent" do
    ua = "Mozilla/5.0 (compatible; test)"
    Current.request_user_agent = ua
    assert_equal ua, Current.request_user_agent
  end

  test "sets and retrieves request_started_at" do
    time = Time.current
    Current.request_started_at = time
    assert_equal time, Current.request_started_at
  end

  test "returns nil duration_ms when request_started_at is nil" do
    Current.request_started_at = nil
    assert_nil Current.duration_ms
  end

  test "returns nil db_time_ms when db_start_time is nil" do
    Current.db_start_time = nil
    assert_nil Current.db_time_ms
  end

  test "returns nil view_time_ms when view_start_time is nil" do
    Current.view_start_time = nil
    assert_nil Current.view_time_ms
  end

  test "resets all attributes" do
    Current.request_id = "abc-123"
    Current.request_ip = "192.0.2.1"
    Current.request_user_agent = "TestAgent/1.0"

    Current.reset

    assert_nil Current.request_id
    assert_nil Current.request_ip
    assert_nil Current.request_user_agent
  end

  test "thread isolation works for request_id" do
    Current.request_id = "req-1"

    other_request_id = nil
    thread = Thread.new do
      Current.request_id = "req-2"
      other_request_id = Current.request_id
    end
    thread.join

    # Main thread should still have req-1
    assert_equal "req-1", Current.request_id
    # Other thread should have req-2
    assert_equal "req-2", other_request_id
  end

  test "multiple attributes work together" do
    start_time = Time.current

    Current.request_id = "req-789"
    Current.request_ip = "10.0.0.1"
    Current.request_user_agent = "TestAgent/1.0"
    Current.request_started_at = start_time

    assert_equal "req-789", Current.request_id
    assert_equal "10.0.0.1", Current.request_ip
    assert_equal "TestAgent/1.0", Current.request_user_agent
    assert_equal start_time, Current.request_started_at
  end

  test "duration_ms can be set and retrieved" do
    Current.duration_ms = 123.45
    assert_equal 123.45, Current.duration_ms
  end

  test "explicit duration_ms overrides calculated duration" do
    Current.request_started_at = 1.second.ago
    Current.duration_ms = 500.0  # Explicitly set to 500ms

    # Should return the explicitly set value, not calculated
    assert_equal 500.0, Current.duration_ms
  end

  test "db_time_ms can be calculated" do
    Current.db_start_time = 0.5.seconds.ago
    db_time = Current.db_time_ms

    # Should be approximately 500ms
    assert db_time > 400
    assert db_time < 600
  end

  test "view_time_ms can be calculated" do
    Current.view_start_time = 0.2.seconds.ago
    view_time = Current.view_time_ms

    # Should be approximately 200ms
    assert view_time > 100
    assert view_time < 300
  end

  test "all timing attributes work together" do
    base_time = 5.seconds.ago
    Current.request_started_at = base_time
    Current.db_start_time = 3.seconds.ago
    Current.view_start_time = 1.second.ago

    # Duration should be calculated from request_started_at
    duration = Current.duration_ms
    assert_not_nil duration
    assert duration > 4500  # Should be > 4.5 seconds
    assert duration < 5500  # Should be < 5.5 seconds

    # db_time and view_time should also calculate
    db_time = Current.db_time_ms
    view_time = Current.view_time_ms
    assert_not_nil db_time
    assert_not_nil view_time
  end

  test "duration_ms returns float with proper precision" do
    Current.duration_ms = 123.456
    duration = Current.duration_ms

    # Should be float
    assert_kind_of Float, duration
    assert_equal 123.456, duration
  end

  test "can store complex request context" do
    request_data = {
      id: "req-123",
      ip: "192.0.2.1",
      user_agent: "Mozilla/5.0",
      timestamp: Time.current
    }

    Current.request_id = request_data[:id]
    Current.request_ip = request_data[:ip]
    Current.request_user_agent = request_data[:user_agent]
    Current.request_started_at = request_data[:timestamp]

    assert_equal request_data[:id], Current.request_id
    assert_equal request_data[:ip], Current.request_ip
    assert_equal request_data[:user_agent], Current.request_user_agent
    assert_equal request_data[:timestamp], Current.request_started_at
  end
end
