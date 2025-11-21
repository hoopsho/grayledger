class CreateMetrics < ActiveRecord::Migration[8.1]
  def change
    create_table :metrics do |t|
      # Metric identification
      t.string :metric_name, null: false
      t.string :metric_type, null: false  # 'counter', 'gauge', or 'timing'

      # Metric value (stored as decimal to handle large integers and floats)
      t.decimal :value, precision: 20, scale: 4, null: false

      # Tags for filtering and grouping (JSONB for efficient querying)
      t.jsonb :tags, default: {}

      # Timestamp when metric was recorded
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    # Index on metric name for fast lookups by metric type
    add_index :metrics, :metric_name

    # Index on metric type for filtering by type
    add_index :metrics, :metric_type

    # Index on recorded_at for time-range queries
    add_index :metrics, :recorded_at

    # GIN index on tags for JSONB queries (allows efficient filtering)
    add_index :metrics, :tags, using: :gin

    # Composite index for common queries (name + time range)
    add_index :metrics, [:metric_name, :recorded_at]

    # Composite index for type + time range queries
    add_index :metrics, [:metric_type, :recorded_at]

    # Add constraint to ensure valid metric types
    execute <<-SQL
      ALTER TABLE metrics
      ADD CONSTRAINT valid_metric_type
      CHECK (metric_type IN ('counter', 'gauge', 'timing'))
    SQL
  end
end
