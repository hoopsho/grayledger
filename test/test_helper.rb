# SimpleCov coverage tracking must be started FIRST, before Rails loads [TASK-3.3]
require "simplecov"
SimpleCov.start

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Load VCR configuration for HTTP request recording [TASK-3.2]
require "support/vcr"

# Ensure solid_cache_entries table exists for all test workers [TASK-5.1]
ActiveRecord::Base.establish_connection :cache
unless ActiveRecord::Base.connection.table_exists?(:solid_cache_entries)
  ActiveRecord::Schema[8.1].define do
    create_table :solid_cache_entries, force: :cascade do |t|
      t.binary :key, limit: 1024, null: false
      t.binary :value, limit: 536870912, null: false
      t.datetime :created_at, null: false
      t.bigint :key_hash, null: false
      t.integer :byte_size, null: false

      t.index [:key_hash], name: "index_solid_cache_entries_on_key_hash", unique: true
      t.index [:byte_size], name: "index_solid_cache_entries_on_byte_size"
      t.index [:key_hash, :byte_size], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    end
  end
end
# Restore default connection for tests
ActiveRecord::Base.establish_connection :primary

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
