class CreateAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :alerts do |t|
      # Alert type and identification
      t.string :alert_type, null: false
      t.string :metric_name, null: false

      # Current metric value and threshold
      t.decimal :current_value, precision: 12, scale: 4, null: false
      t.decimal :threshold, precision: 12, scale: 4, null: false

      # Lifecycle timestamps
      t.datetime :triggered_at, null: false
      t.datetime :resolved_at

      # Metadata for context
      t.text :description

      t.timestamps
    end

    # Indexes for fast querying
    add_index :alerts, [:alert_type, :triggered_at], name: "index_alerts_by_type_and_time"
    add_index :alerts, [:metric_name, :triggered_at], name: "index_alerts_by_metric_and_time"
    add_index :alerts, [:resolved_at], name: "index_alerts_by_resolved"
    add_index :alerts, [:triggered_at], name: "index_alerts_by_triggered_time"
  end
end
