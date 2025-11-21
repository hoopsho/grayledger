class CreateInvoiceItems < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_items do |t|
      # Monetized columns following ADR-01.001 Money pattern
      # amount_cents stored as integer to avoid floating-point precision errors
      t.integer :amount_cents, null: false, default: 0
      t.string :amount_currency, null: false, default: 'USD'

      t.timestamps
    end

    # Index on amount_cents for queries (e.g., summing by range)
    add_index :invoice_items, :amount_cents
  end
end
