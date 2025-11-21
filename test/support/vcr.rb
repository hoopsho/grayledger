begin
  require "vcr"
  require "webmock"

  # Configure VCR for recording and replaying HTTP interactions
  # VCR is used to record HTTP requests/responses as cassettes for testing
  # without making real HTTP calls during test runs
  VCR.configure do |config|
    config.cassette_library_dir = "test/vcr_cassettes"
    config.hook_into :webmock

    # Recording mode:
    # - :once      - Record on first run, replay on subsequent runs (default)
    # - :new_episodes - Record new cassettes, replay existing ones
    # - :none      - Never record, only replay (for CI/CD)
    # - :all       - Always record, never use existing cassettes
    # Note: VCR 6.x uses 'record:' instead of 'record_mode='
    config.define_cassette_placeholder("<PASSWORD>", "password")
    config.allow_http_connections_when_no_cassette = false

    # Configuration for specific cassettes
    config.default_cassette_options = {
      record: :once,
      decode_compressed_response: true,
      allow_playback_repeats: true
    }
  end

  # Helper to record HTTP interactions
  def use_cassette(name, &block)
    VCR.use_cassette(name, &block)
  end
rescue LoadError
  # VCR and WebMock are only available in test environment
  # This prevents errors when test_helper is loaded in other contexts
end
