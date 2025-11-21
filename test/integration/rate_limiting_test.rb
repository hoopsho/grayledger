# frozen_string_literal: true

require "test_helper"

# Integration Tests for Rack::Attack Rate Limiting Rules
# TASK-4.2: Tests for OTP and API rate limiting rules
# TASK-4.3: Tests for rate limit response headers
#
# This test suite verifies that all rate limiting rules work correctly:
# 1. OTP generation throttle (3 per 15 minutes)
# 2. OTP validation throttle (5 per 10 minutes)
# 3. Receipt upload throttle (50 per hour)
# 4. AI categorization throttle (200 per hour)
# 5. Entry creation throttle (100 per hour)
# 6. General API throttle (1000 per hour)
#
# Note: Tests use a spoofed IP address (192.0.2.1) to bypass the localhost
# safelist, which is important for verifying rate limiting behavior.

class RateLimitingTest < ActionDispatch::IntegrationTest
  # Setup: Use a spoofed IP to bypass localhost safelist
  def setup
    super
    Rails.cache.clear
    Rack::Attack.cache.store = Rails.cache
    @test_ip = "192.0.2.1"  # TEST-NET-1 reserved IP (RFC 5737)
  end

  # Helper method to make requests with a spoofed IP
  def post_with_ip(path, ip = @test_ip)
    post path, headers: { "REMOTE_ADDR" => ip }
  end

  def get_with_ip(path, ip = @test_ip)
    get path, headers: { "REMOTE_ADDR" => ip }
  end

  # ============================================================================
  # TEST SUITE 1: OTP Generation Throttle (3 per 15 minutes)
  # ============================================================================

  test "otp/generation: allows 3 requests per 15 minutes" do
    # First 3 requests should succeed
    3.times do |i|
      post_with_ip "/test_otp_generation"
      assert_response :ok, "Request #{i + 1} should succeed"
    end
  end

  test "otp/generation: throttles after 3 requests per 15 minutes" do
    # Make 3 successful requests
    3.times { post_with_ip "/test_otp_generation" }

    # 4th request should be throttled
    post_with_ip "/test_otp_generation"
    assert_response :too_many_requests, "4th request should be throttled (429)"
    assert_equal "3", response.headers["X-RateLimit-Limit"]
    assert_equal "0", response.headers["X-RateLimit-Remaining"]
  end

  test "otp/generation: returns JSON error with helpful message" do
    # Make 3 successful requests
    3.times { post_with_ip "/test_otp_generation" }

    # 4th request should be throttled with JSON error
    post_with_ip "/test_otp_generation"
    assert_response :too_many_requests
    body = JSON.parse(response.body)
    assert_equal "Rate limit exceeded", body["error"]
    assert body["message"].present?
    assert_equal 3, body["limit"]
  end

  # ============================================================================
  # TEST SUITE 2: OTP Validation Throttle (5 per 10 minutes)
  # ============================================================================

  test "otp/validation: allows 5 requests per 10 minutes" do
    # First 5 requests should succeed
    5.times do |i|
      post_with_ip "/test_otp_validation"
      assert_response :ok, "Request #{i + 1} should succeed"
    end
  end

  test "otp/validation: throttles after 5 requests per 10 minutes" do
    # Make 5 successful requests
    5.times { post_with_ip "/test_otp_validation" }

    # 6th request should be throttled
    post_with_ip "/test_otp_validation"
    assert_response :too_many_requests, "6th request should be throttled (429)"
    assert_equal "5", response.headers["X-RateLimit-Limit"]
  end

  # ============================================================================
  # TEST SUITE 3: Receipt Upload Throttle (50 per hour)
  # ============================================================================

  test "receipt/upload: allows 50 requests per hour" do
    # Test with a sample of requests
    10.times do |i|
      post_with_ip "/test_receipt_upload"
      assert_response :ok, "Request #{i + 1} should succeed"
    end
  end

  test "receipt/upload: throttles after 50 requests per hour" do
    # Make 50 successful requests
    50.times { post_with_ip "/test_receipt_upload" }

    # 51st request should be throttled
    post_with_ip "/test_receipt_upload"
    assert_response :too_many_requests
    assert_equal "50", response.headers["X-RateLimit-Limit"]
  end

  # ============================================================================
  # TEST SUITE 4: AI Categorization Throttle (200 per hour)
  # ============================================================================

  test "ai/categorization: allows 200 requests per hour" do
    # Test with a sample of requests
    10.times do |i|
      post_with_ip "/test_ai_categorization"
      assert_response :ok, "Request #{i + 1} should succeed"
    end
  end

  test "ai/categorization: returns correct limit" do
    post_with_ip "/test_ai_categorization"
    assert_response :ok
    assert_equal "200", response.headers["X-RateLimit-Limit"]
  end

  # ============================================================================
  # TEST SUITE 5: Entry Creation Throttle (100 per hour)
  # ============================================================================

  test "entry/creation: allows 100 requests per hour" do
    # Test with a sample of requests
    10.times do |i|
      post_with_ip "/test_entry_creation"
      assert_response :ok, "Request #{i + 1} should succeed"
    end
  end

  test "entry/creation: returns correct limit" do
    post_with_ip "/test_entry_creation"
    assert_response :ok
    assert_equal "100", response.headers["X-RateLimit-Limit"]
  end

  # ============================================================================
  # TEST SUITE 6: General API Throttle (1000 per hour)
  # ============================================================================

  test "api/general: allows 1000 requests per hour" do
    # Test with a sample of requests
    10.times do |i|
      post_with_ip "/test_general_api"
      assert_response :ok, "Request #{i + 1} should succeed"
    end
  end

  test "api/general: works with both POST and GET" do
    post_with_ip "/test_general_api"
    assert_response :ok
    assert_equal "1000", response.headers["X-RateLimit-Limit"]

    get_with_ip "/test_general_api"
    assert_response :ok
  end

  # ============================================================================
  # TEST SUITE 7: Rate Limit Headers on Successful Responses
  # ============================================================================

  test "successful responses include X-RateLimit-* headers" do
    post_with_ip "/test_otp_generation"
    assert_response :ok
    assert_not_nil response.headers["X-RateLimit-Limit"]
    assert_not_nil response.headers["X-RateLimit-Remaining"]
    assert_not_nil response.headers["X-RateLimit-Reset"]
  end

  test "X-RateLimit-Remaining decreases with each request" do
    post_with_ip "/test_otp_generation"
    first_remaining = response.headers["X-RateLimit-Remaining"].to_i

    post_with_ip "/test_otp_generation"
    second_remaining = response.headers["X-RateLimit-Remaining"].to_i

    assert second_remaining < first_remaining
  end

  test "X-RateLimit-Reset is Unix timestamp in future" do
    post_with_ip "/test_otp_generation"
    reset_time = response.headers["X-RateLimit-Reset"].to_i
    assert reset_time > Time.now.to_i
  end

  # ============================================================================
  # TEST SUITE 8: Rate Limit Headers on Throttled Responses
  # ============================================================================

  test "throttled responses include Retry-After header" do
    # Make 3 successful OTP generation requests
    3.times { post_with_ip "/test_otp_generation" }

    # 4th request should be throttled
    post_with_ip "/test_otp_generation"
    assert_response :too_many_requests
    assert_not_nil response.headers["Retry-After"]
    assert response.headers["Retry-After"].to_i > 0
  end

  test "throttled response Content-Type is application/json" do
    # Make 50 successful receipt upload requests
    50.times { post_with_ip "/test_receipt_upload" }

    # 51st request should be throttled
    post_with_ip "/test_receipt_upload"
    assert_response :too_many_requests
    assert_equal "application/json", response.headers["Content-Type"]
  end

  # ============================================================================
  # TEST SUITE 9: Throttle Rules Apply Per IP
  # ============================================================================

  test "throttle counts are per IP" do
    # IP 1: Make 3 OTP generation requests
    3.times { post_with_ip "/test_otp_generation", "192.0.2.1" }

    # 4th request from IP 1 should be throttled
    post_with_ip "/test_otp_generation", "192.0.2.1"
    assert_response :too_many_requests

    # But requests from a different IP should work
    post_with_ip "/test_otp_generation", "192.0.2.2"
    assert_response :ok
  end

  # ============================================================================
  # TEST SUITE 10: Different Rules Are Independent
  # ============================================================================

  test "OTP generation and OTP validation throttles are independent" do
    ip = "192.0.2.100"

    # Make 3 OTP generation requests (hits OTP generation limit)
    3.times { post_with_ip "/test_otp_generation", ip }

    # OTP generation should be throttled
    post_with_ip "/test_otp_generation", ip
    assert_response :too_many_requests

    # But OTP validation should still work
    post_with_ip "/test_otp_validation", ip
    assert_response :ok
  end

  test "different API endpoints have separate limits" do
    ip = "192.0.2.200"

    # Make 50 receipt upload requests
    50.times { post_with_ip "/test_receipt_upload", ip }

    # Receipt upload should be throttled
    post_with_ip "/test_receipt_upload", ip
    assert_response :too_many_requests

    # But other endpoints should still work
    post_with_ip "/test_otp_generation", ip
    assert_response :ok
  end

  # ============================================================================
  # TEST SUITE 11: Error Response Details
  # ============================================================================

  test "throttle error includes all required fields" do
    ip = "192.0.2.50"

    # Make 3 OTP generation requests
    3.times { post_with_ip "/test_otp_generation", ip }

    # 4th request should be throttled
    post_with_ip "/test_otp_generation", ip
    body = JSON.parse(response.body)

    # Verify all required fields are present
    assert body.key?("error")
    assert body.key?("message")
    assert body.key?("limit")
    assert body.key?("current_count")
    assert body.key?("remaining")
    assert body.key?("retry_after")
    assert body.key?("reset_at")
  end

  # ============================================================================
  # CLEANUP AND HELPER METHODS
  # ============================================================================

  # Override teardown to reset rate limit counters between tests
  def teardown
    super
    # Clear Rails.cache to reset rate limit counters
    Rails.cache.clear if Rails.cache.respond_to?(:clear)
  end
end
