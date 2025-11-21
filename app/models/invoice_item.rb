class InvoiceItem < ApplicationRecord
  # Use money-rails for monetary value handling
  # Converts amount_cents/amount_currency columns to Money objects
  monetize :amount_cents
end
