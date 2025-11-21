require "etc"

namespace :solid_cache do
  desc "Create solid_cache tables in test database (parallel workers handle their own)"
  task :setup_test_tables => :environment do
    if ENV["RAILS_ENV"] == "test"
      begin
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
          puts "Created solid_cache_entries table"
        end
      rescue ActiveRecord::NoDatabaseError
        puts "Cache database not yet created (will be handled by db:prepare)"
      ensure
        ActiveRecord::Base.establish_connection :primary
      end
    end
  end
end

# Hook into db:prepare to also setup solid_cache tables
Rake::Task["db:prepare"].enhance do
  if ENV["RAILS_ENV"] == "test"
    Rake::Task["solid_cache:setup_test_tables"].invoke
  end
end
