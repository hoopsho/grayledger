require "test_helper"

# Sample test demonstrating VCR usage for recording HTTP interactions
# This test demonstrates how VCR records and replays HTTP requests
class VCRSampleTest < ActionDispatch::IntegrationTest
  # Test that VCR records and replays HTTP requests to external services
  test "records and replays HTTP request to example.com" do
    VCR.use_cassette("example_com_home") do
      # This request will be recorded on first run, then replayed on subsequent runs
      response = Net::HTTP.get_response(URI("http://example.com/"))

      assert_not_nil response
      assert_equal "200", response.code
      assert response.body.include?("Example Domain")
    end
  end

  # Test that VCR cassette persists data across test runs
  test "cassette file is created for recorded interactions" do
    VCR.use_cassette("example_com_alternative") do
      Net::HTTP.get_response(URI("http://example.com/"))
    end

    # Verify cassette was created (note: cassettes are YAML files)
    cassette_path = Rails.root.join("test/vcr_cassettes/example_com_alternative.yml")
    assert File.exist?(cassette_path), "VCR cassette should be created at #{cassette_path}"
  end

  # Test that VCR properly blocks unhandled HTTP requests
  test "VCR blocks unhandled external requests outside of cassettes" do
    # VCR should raise an UnhandledHTTPRequestError when trying to make a request
    # outside of a cassette (with allow_http_connections_when_no_cassette = false)
    assert_raises VCR::Errors::UnhandledHTTPRequestError do
      Net::HTTP.get_response(URI("http://example.com/test-that-does-not-exist-in-cassette"))
    end
  end
end
