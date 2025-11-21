class CreateMetricRollups < ActiveRecord::Migration[8.1]
  def change
    create_table :metric_rollups do |t|
      # Metric identification
      t.string :metric_name, null: false, comment: "e.g., 'api.response_time', 'cache.hit_rate'"
      t.string :metric_type, null: false, comment: "counter, gauge, histogram"

      # Rollup period
      t.string :rollup_interval, null: false, comment: "hourly, daily, weekly"
      t.datetime :aggregated_at, null: false, comment: "Time period this rollup covers"

      # Aggregated statistics (stored as JSON for flexibility)
      # For counters: {sum: X, count: X}
      # For gauges: {avg: X, min: X, max: X, latest: X}
      # For histograms: {sum: X, avg: X, min: X, max: X, p50: X, p95: X, p99: X, count: X}
      t.jsonb :statistics, null: false, default: {}, comment: "Aggregated statistics"

      # Metadata
      t.text :description
      t.integer :sample_count, default: 0, null: false, comment: "Number of samples included in rollup"

      t.timestamps
    end

    # Indexes for fast querying
    add_index :metric_rollups, [:metric_name, :rollup_interval, :aggregated_at],
              name: "index_metric_rollups_by_metric_and_interval_and_time"
    add_index :metric_rollups, [:rollup_interval, :aggregated_at],
              name: "index_metric_rollups_by_interval_and_time"
    add_index :metric_rollups, [:metric_name, :aggregated_at],
              name: "index_metric_rollups_by_metric_and_time"
    add_index :metric_rollups, [:aggregated_at],
              name: "index_metric_rollups_by_time"
    add_index :metric_rollups, [:metric_type],
              name: "index_metric_rollups_by_type"
  end
end
