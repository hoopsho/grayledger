# frozen_string_literal: true

# Test Controller for Rate Limiting Integration Tests
# TASK-4.4: Integration tests for rate limiting rules
#
# This controller provides endpoints for testing each rate limiting rule
# without requiring actual auth or database models. Used only in test environment.

class TestThrottleController < ApplicationController
  skip_before_action :verify_authenticity_token  # Allow test requests without CSRF token

  # Test endpoint for OTP generation throttle
  def otp_generation
    render json: {message: "OTP generation test"}, status: :ok
  end

  # Test endpoint for OTP validation throttle
  def otp_validation
    render json: {message: "OTP validation test"}, status: :ok
  end

  # Test endpoint for receipt upload throttle
  def receipt_upload
    render json: {message: "Receipt upload test"}, status: :ok
  end

  # Test endpoint for AI categorization throttle
  def ai_categorization
    render json: {message: "AI categorization test"}, status: :ok
  end

  # Test endpoint for entry creation throttle
  def entry_creation
    render json: {message: "Entry creation test"}, status: :ok
  end

  # Test endpoint for general API throttle
  def general_api
    render json: {message: "General API test"}, status: :ok
  end
end
