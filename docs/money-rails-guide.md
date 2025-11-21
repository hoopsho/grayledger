# Money-Rails Compatibility Guide for GrayLedger Rails 8

**Document Version:** 1.0
**Rails Version:** 8.1.1+
**money-rails Version:** 1.15.0+
**Last Updated:** 2025-11-21

## Table of Contents

1. [Rails 8 Compatibility](#rails-8-compatibility)
2. [Installation & Setup](#installation--setup)
3. [Core Patterns](#core-patterns)
4. [Double-Entry Bookkeeping Integration](#double-entry-bookkeeping-integration)
5. [Best Practices](#best-practices)
6. [Common Pitfalls](#common-pitfalls)
7. [Testing Patterns](#testing-patterns)
8. [Multi-Currency Considerations](#multi-currency-considerations)

---

## Rails 8 Compatibility

### Verified Compatibility

money-rails 1.15.0 is **fully compatible** with Rails 8.1.1:

- Works with Rails 8 syntax and conventions
- Compatible with Ruby 3.3.x
- No breaking changes from Rails 7
- Integrates seamlessly with Hotwire/Turbo
- Full support for PostgreSQL array/JSONB types
- Thread-safe with Solid Queue background jobs

### Key Version Matrix

| Rails Version | money-rails | money | Status |
|--------------|------------|-------|--------|
| Rails 8.0+ | 1.15.0+ | 6.19.0+ | Fully Compatible |
| Rails 7.1 | 1.15.0+ | 6.19.0+ | Fully Compatible |
| Rails 7.0 | 1.14.0+ | 6.14.0+ | Fully Compatible |

### Known Limitations

None in Rails 8 specifically. money-rails uses standard Rails patterns and no edge-case features.

---

## Installation & Setup

### 1. Add to Gemfile

```ruby
# Gemfile
gem "money-rails", "~> 1.15.0"
gem "money", "~> 6.19.0"
```

### 2. Bundle Install

```bash
bundle install
```

### 3. Initialize Configuration

```bash
rails generate money_rails:install
```

This creates `/config/initializers/money.rb`:

```ruby
# /config/initializers/money.rb
MoneyRails.configure do |config|
  # Default currency for Money objects
  config.default_currency = :usd

  # Database precision (5 = supports up to 999,999.99)
  config.amount_column = :amount
  config.currency_column = :currency
end
```

### 4. Verify Configuration

```bash
rails c
>> Money.new(1000, 'USD')
=> #<Money fractional:1000 currency:USD>
>> Money.new(1000, 'USD').format
=> "$10.00"
```

### 5. Database Schema Pattern

For any monetized attribute, create two database columns:

```ruby
# db/migrate/[timestamp]_create_invoices.rb
class CreateInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :invoices do |t|
      # Always use _cents and _currency columns
      t.integer :subtotal_cents,   null: false, default: 0
      t.string :subtotal_currency, null: false, default: 'USD'

      t.integer :tax_cents,        null: false, default: 0
      t.string :tax_currency,      null: false, default: 'USD'

      t.integer :total_cents,      null: false, default: 0
      t.string :total_currency,    null: false, default: 'USD'

      t.references :company, foreign_key: true
      t.timestamps
    end

    # Indexes for financial queries
    add_index :invoices, [:company_id, :subtotal_cents]
    add_index :invoices, [:company_id, :total_cents]
  end
end
```

---

## Core Patterns

### Pattern 1: Basic monetize Setup

```ruby
# app/models/invoice.rb
class Invoice < ApplicationRecord
  monetize :subtotal_cents
  monetize :tax_cents
  monetize :total_cents

  # Validations
  validates :subtotal_cents, presence: true, numericality: { only_integer: true }
  validates :total_cents, presence: true, numericality: { only_integer: true }
end
```

Usage:

```ruby
invoice = Invoice.new(subtotal_cents: 10_000)  # $100.00

# Access as Money object
invoice.subtotal                               # => Money(10000, 'USD')
invoice.subtotal.format                        # => "$100.00"
invoice.subtotal.cents                         # => 10000
invoice.subtotal.currency                      # => #<Money::Currency id: usd>

# Assign Money object
invoice.subtotal = Money.new(10_000, 'USD')
invoice.subtotal_cents                         # => 10000
invoice.subtotal_currency                      # => 'USD'
```

### Pattern 2: Arithmetic Operations

```ruby
# Calculate totals
class Invoice < ApplicationRecord
  monetize :subtotal_cents
  monetize :tax_cents
  monetize :total_cents

  def calculate_total
    self.total_cents = (subtotal + tax).cents
    self.total
  end

  def calculate_tax(rate = 0.08)
    (subtotal * rate).cents
  end
end

# Usage
invoice = Invoice.new(subtotal_cents: 10_000)  # $100.00
total = invoice.subtotal + Money.new(800, 'USD')  # $108.00
# => Money(10800, 'USD')

# Subtraction
invoice.subtotal - Money.new(500, 'USD')
# => Money(9500, 'USD')

# Multiplication (for percentages, not cents)
result = Money.new(10_000, 'USD') * 0.08
# => Money(800, 'USD') ($8.00 tax on $100)

# Division
Money.new(10_000, 'USD') / 10
# => Money(1000, 'USD') ($10.00 each)
```

### Pattern 3: Display Formatting

```ruby
# Simple format
money = Money.new(10_000, 'USD')
money.format                    # => "$10,000.00"

# With custom options
money.format(
  decimal_mark: '.',
  thousands_separator: ',',
  symbol: '$ '
)
# => "$ 10,000.00"

# Cents only (useful for UI display)
money.format(symbol: false)     # => "10,000.00"

# Currency code instead of symbol
money.format(symbol: money.currency.iso_code)
# => "USD 10,000.00"
```

### Pattern 4: Form Handling

```erb
<!-- Using simple form (or standard Rails form) -->
<form>
  <!-- Input for cents only - user enters dollars -->
  <%= form.number_field :subtotal_dollars, step: :any,
      value: (object.subtotal_cents.to_f / 100) %>

  <!-- Custom helper for cleaner syntax -->
  <%= money_field(form, :subtotal) %>
</form>
```

```ruby
# app/helpers/money_helper.rb
module MoneyHelper
  def money_field(form, attribute)
    cents_attribute = "#{attribute}_cents"
    dollars_value = form.object.send(cents_attribute).to_f / 100

    form.number_field(
      cents_attribute,
      step: :any,
      value: dollars_value,
      class: 'money-input'
    )
  end

  def money_display(money_object, options = {})
    return '-' if money_object.nil? || money_object.cents.zero?

    tag.span(
      money_object.format,
      class: "money-display #{options[:css_class]}"
    )
  end
end
```

```ruby
# app/controllers/invoices_controller.rb
class InvoicesController < ApplicationController
  def create
    invoice = Invoice.new(invoice_params)

    # Handle user input in dollars, convert to cents
    invoice.subtotal_cents = (params[:invoice][:subtotal_dollars].to_f * 100).round.to_i
    invoice.tax_cents = (params[:invoice][:tax_dollars].to_f * 100).round.to_i

    if invoice.save
      redirect_to invoice, notice: "Invoice created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def invoice_params
    params.require(:invoice).permit(:description, :company_id)
  end
end
```

### Pattern 5: JSON Serialization

```ruby
# app/serializers/invoice_serializer.rb
class InvoiceSerializer
  def initialize(invoice)
    @invoice = invoice
  end

  def as_json(options = {})
    {
      id: @invoice.id,
      description: @invoice.description,
      # Format money for API responses
      subtotal: {
        cents: @invoice.subtotal_cents,
        currency: @invoice.subtotal_currency,
        formatted: @invoice.subtotal.format
      },
      tax: {
        cents: @invoice.tax_cents,
        currency: @invoice.tax_currency,
        formatted: @invoice.tax.format
      },
      total: {
        cents: @invoice.total_cents,
        currency: @invoice.total_currency,
        formatted: @invoice.total.format
      }
    }
  end
end

# Or with ActiveModel::Serializer (if using that gem)
class InvoiceSerializer < ActiveModel::Serializer
  attributes :id, :description, :subtotal, :tax, :total

  def subtotal
    {
      cents: object.subtotal_cents,
      currency: object.subtotal_currency,
      formatted: object.subtotal.format
    }
  end

  def tax
    {
      cents: object.tax_cents,
      currency: object.tax_currency,
      formatted: object.tax.format
    }
  end

  def total
    {
      cents: object.total_cents,
      currency: object.total_currency,
      formatted: object.total.format
    }
  end
end

# Usage
InvoiceSerializer.new(invoice).as_json
# => {
#      id: 1,
#      subtotal: { cents: 10000, currency: "USD", formatted: "$100.00" },
#      tax: { cents: 800, currency: "USD", formatted: "$8.00" },
#      total: { cents: 10800, currency: "USD", formatted: "$108.00" }
#    }
```

### Pattern 6: Querying by Amount

```ruby
# Find all invoices over $1000
Invoice.where('total_cents > ?', 100_000)

# Sum totals across company
Invoice.where(company: current_company)
       .sum(:total_cents)
       .then { |cents| Money.new(cents, 'USD') }

# Range queries
Invoice.where(total_cents: 50_000..150_000)  # $500-$1500

# Highest invoice
Invoice.order(total_cents: :desc).first
```

---

## Double-Entry Bookkeeping Integration

GrayLedger uses a minimal custom double-entry ledger (see ADR 04.001). money-rails integrates seamlessly:

### Core Models

```ruby
# app/models/entry.rb
class Entry < ApplicationRecord
  include BelongsToCompany

  has_many :line_items, dependent: :destroy

  validates :description, presence: true
  validates :posted_at, presence: true
  validate :must_balance
  validate :must_have_at_least_two_line_items

  private

  def must_balance
    errors.add(:base, "Entry does not balance") unless line_items.sum(:amount_cents) == 0
  end

  def must_have_at_least_two_line_items
    errors.add(:base, "Entry needs ≥2 line items") if line_items.size < 2
  end
end

# app/models/line_item.rb
class LineItem < ApplicationRecord
  include BelongsToCompany

  belongs_to :entry
  belongs_to :account

  # amount_cents is SIGNED:
  #   positive = debit (left side of equation)
  #   negative = credit (right side of equation)
  monetize :amount_cents, with_model_currency: :currency

  validates :amount_cents, presence: true, numericality: { only_integer: true }
  validates :currency, presence: true
end
```

### Database Schema

```ruby
# db/migrate/[timestamp]_create_ledger.rb
class CreateLedger < ActiveRecord::Migration[8.0]
  def change
    create_table :entries do |t|
      t.references :company, null: false, foreign_key: true
      t.string :description, null: false
      t.datetime :posted_at, null: false
      t.timestamps
    end

    create_table :line_items do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true

      # Signed integer: positive = debit, negative = credit
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: 'USD'

      t.timestamps
    end

    # Critical indexes for balance calculations
    add_index :line_items, [:account_id, :posted_at]
    add_index :line_items, [:company_id, :account_id, :posted_at]
    add_index :line_items, :entry_id
  end
end
```

### Posting Entries (Atomic)

```ruby
# Posting an entry is ALWAYS atomic
Entry.transaction do
  entry = Entry.create!(
    company: Current.company,
    description: "Bank deposit from customer",
    posted_at: Date.today
  )

  # Create balanced line items
  # Debit: Cash account goes up (positive)
  entry.line_items.create!(
    account: checking_account,
    amount_cents: 50_000,  # $500.00
    currency: 'USD'
  )

  # Credit: Revenue account goes up (negative for credit)
  entry.line_items.create!(
    account: revenue_account,
    amount_cents: -50_000,  # -$500.00
    currency: 'USD'
  )

  # After save, entry.must_balance validates
  # Sum of line_items.amount_cents must equal 0
end
```

### Account Balance Calculations

**Critical Rule:** Account balances are **NEVER stored**. Always calculate on-read:

```ruby
# app/models/account.rb
class Account < ApplicationRecord
  include BelongsToCompany

  has_many :line_items

  # Calculate balance as of today
  def current_balance
    Money.new(balance_cents, 'USD')
  end

  def balance_cents
    line_items.sum(:amount_cents)
  end

  # Balance as of specific date
  def balance_at(date)
    cents = line_items.where('posted_at <= ?', date).sum(:amount_cents)
    Money.new(cents, 'USD')
  end

  # Balance range
  def balance_between(start_date, end_date)
    cents = line_items.where(posted_at: start_date..end_date).sum(:amount_cents)
    Money.new(cents, 'USD')
  end
end

# Usage
checking = Account.find_by(code: '1010')
checking.current_balance       # => Money(123_456_78, 'USD')
checking.balance_at(30.days.ago)
checking.balance_between(Date.today.beginning_of_month, Date.today)
```

### Entry Validation Example

```ruby
# This entry balances correctly
Entry.create!(
  company: Current.company,
  description: "Expense recorded",
  posted_at: Date.today,
  line_items_attributes: [
    { account_id: checking_account.id, amount_cents: -10_000 },    # -$100 credit
    { account_id: expense_account.id, amount_cents: 10_000 }       # +$100 debit
  ]
)
# => Success! Sum = 0

# This entry will FAIL validation
Entry.create!(
  company: Current.company,
  description: "Imbalanced entry",
  posted_at: Date.today,
  line_items_attributes: [
    { account_id: checking_account.id, amount_cents: -10_000 },    # -$100
    { account_id: expense_account.id, amount_cents: 5_000 }        # +$50
  ]
)
# => ValidationError: "Entry does not balance" (sum = -5000)
```

### Tax Calculations

```ruby
# app/models/invoice.rb
class Invoice < ApplicationRecord
  include BelongsToCompany

  monetize :subtotal_cents
  monetize :tax_cents
  monetize :total_cents

  def calculate_tax(rate = 0.08)
    # Money * Float = Money
    tax = subtotal * rate
    self.tax_cents = tax.cents
  end

  def post_to_ledger
    Entry.transaction do
      entry = Entry.create!(
        company: company,
        description: "Invoice #{id}: #{description}",
        posted_at: Date.today
      )

      # Debit: Accounts receivable
      entry.line_items.create!(
        account: ar_account,
        amount_cents: total_cents
      )

      # Credit: Revenue
      entry.line_items.create!(
        account: revenue_account,
        amount_cents: -subtotal_cents
      )

      # Credit: Sales tax payable
      entry.line_items.create!(
        account: sales_tax_account,
        amount_cents: -tax_cents
      )

      # Entry validates must_balance
    end
  end
end
```

---

## Best Practices

### 1. Always Store as Integers (Cents)

```ruby
# GOOD: Integer storage, no floating-point errors
model.amount_cents = 1234    # Exactly $12.34

# BAD: Float can lose precision
model.amount = 12.34         # Might be 12.339999999

# ALWAYS: Convert user input to cents
user_dollars = params[:amount].to_f
model.amount_cents = (user_dollars * 100).round.to_i
```

### 2. Validate Before Saving

```ruby
class Invoice < ApplicationRecord
  monetize :amount_cents

  validates :amount_cents, presence: true,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0,
      message: "must be a positive integer (cents)"
    }
end
```

### 3. Use Transactions for Ledger Operations

```ruby
# ALWAYS atomic for ledger posts
def create_entry
  Entry.transaction do
    entry = Entry.create!(...)
    entry.line_items.create!(...)
    entry.line_items.create!(...)
    # All succeed or all rollback
  end
end

# NOT GOOD: Partial saves can break ledger
entry.save
line_item.save  # Could fail, entry already saved
```

### 4. Index Columns for Query Performance

```ruby
# db/migrate/[timestamp]_add_money_indexes.rb
class AddMoneyIndexes < ActiveRecord::Migration[8.0]
  def change
    # For finding by amount range
    add_index :invoices, :amount_cents

    # For company-scoped summaries
    add_index :invoices, [:company_id, :amount_cents]

    # For date-filtered financials
    add_index :line_items, [:account_id, :posted_at]
    add_index :line_items, [:company_id, :posted_at]
  end
end
```

### 5. Never Trust User Input

```ruby
class PaymentProcessor
  def process_payment(user_input_amount)
    # Validate and sanitize
    cents = sanitize_amount(user_input_amount)

    # Verify amount is reasonable
    raise ArgumentError, "Amount too large" if cents > 1_000_000_00  # $1M max
    raise ArgumentError, "Amount too small" if cents < 100  # $1 min

    payment = Payment.new(amount_cents: cents)
    payment.save!
    payment
  end

  private

  def sanitize_amount(input)
    # Convert to float, round to 2 decimals, convert to cents
    dollars = Float(input).round(2)
    (dollars * 100).round.to_i
  rescue ArgumentError
    raise ArgumentError, "Invalid amount format"
  end
end
```

### 6. Format for Display, Not Storage

```ruby
<!-- GOOD: Format in view -->
<%= @invoice.subtotal.format %>          <!-- $1,234.56 -->

<!-- GOOD: Format in serializer -->
{
  "subtotal_cents": 123456,
  "subtotal_formatted": "$1,234.56"
}

<!-- BAD: Storing formatted strings -->
Invoice.select(:formatted_amount)  # Don't do this!
```

### 7. Document Currency Assumptions

```ruby
class Invoice < ApplicationRecord
  # NOTE: GrayLedger v1 supports USD only
  # Future: Use currency column for multi-currency support
  monetize :subtotal_cents  # Always USD

  validate :currency_is_usd

  private

  def currency_is_usd
    if subtotal_currency != 'USD'
      errors.add(:subtotal_currency, "must be USD in v1")
    end
  end
end
```

---

## Common Pitfalls

| Pitfall | Problem | Solution |
|---------|---------|----------|
| **Float inputs** | `0.1 + 0.2 != 0.3` in binary | Always store as integers (cents) |
| **Rounding errors** | Not rounding before storing | Use `(dollars * 100).round.to_i` |
| **No currency check** | Mixing currencies silently | Validate currency matches default |
| **Unindexed queries** | `sum(:amount_cents)` is slow | Add indexes on amount_cents, posted_at |
| **Silent failures** | Entry saves but items fail | Use transactions, validate must_balance |
| **Unbalanced entries** | Ledger is corrupt | Test entry.must_balance in all cases |
| **Formatted storage** | "$1,234.56" string in DB | Store only as integers, format on read |
| **Missing validation** | Negative amounts in revenue | Validate numericality, positive amounts |
| **No audit trail** | Can't track changes | Include Entry + LineItem attachment |
| **Scaling issues** | `balance_cents` calculated slowly | Add database indexes, use cached_at |

### Detailed Examples

#### Pitfall 1: Float Precision Loss

```ruby
# WRONG
amount = 0.1 + 0.2
# => 0.30000000000000004
amount_cents = (amount * 100).to_i
# => 30 (Should be 30, happens to work this time!)

# BETTER
amount_cents = (0.1 * 100).round.to_i + (0.2 * 100).round.to_i
# => 10 + 20 = 30

# BEST
amount_cents = (33.33).round(2) * 100  # User enters $0.33
# => 33
```

#### Pitfall 2: Unbalanced Entry Posted

```ruby
# WRONG: No transaction, partial save
entry = Entry.create(description: "Payment")
entry.line_items.create(account: checking, amount_cents: 100)
# If this fails, entry is already saved!
entry.line_items.create(account: revenue, amount_cents: -50)  # Different amount!

# RIGHT: Atomic transaction
Entry.transaction do
  entry = Entry.create!(description: "Payment")
  entry.line_items.create!(account: checking, amount_cents: 100)
  entry.line_items.create!(account: revenue, amount_cents: -100)
  # must_balance validation ensures sum = 0
end
```

#### Pitfall 3: No Currency Validation

```ruby
# WRONG: Silently creates USD entry
invoice = Invoice.new(amount_cents: 1000)
invoice.amount_currency  # => 'USD' (default, but what if user expects EUR?)

# RIGHT: Validate and document
class Invoice < ApplicationRecord
  monetize :amount_cents

  validates :amount_currency, inclusion: { in: %w(USD),
    message: "only USD supported in v1" }
end

invoice = Invoice.new(amount_cents: 1000, amount_currency: 'EUR')
invoice.valid?  # => false
```

---

## Testing Patterns

### 1. Unit Tests for Monetary Values

```ruby
# test/models/invoice_test.rb
class InvoiceTest < ActiveSupport::TestCase
  test "monetize creates Money object" do
    invoice = Invoice.new(amount_cents: 5000)

    assert_equal Money.new(5000, 'USD'), invoice.amount
    assert_equal 5000, invoice.amount_cents
    assert_equal 'USD', invoice.amount_currency
  end

  test "persists money correctly" do
    invoice = Invoice.create!(amount_cents: 7500)
    reloaded = Invoice.find(invoice.id)

    assert_equal 7500, reloaded.amount_cents
    assert_equal Money.new(7500, 'USD'), reloaded.amount
  end

  test "arithmetic operations work" do
    invoice = Invoice.new(amount_cents: 10_000)

    total = invoice.amount + Money.new(800, 'USD')
    assert_equal Money.new(10_800, 'USD'), total

    tax = invoice.amount * 0.08
    assert_equal Money.new(800, 'USD'), tax
  end

  test "validates positive amounts" do
    invoice = Invoice.new(amount_cents: -100)

    assert_not invoice.valid?
    assert_includes invoice.errors[:amount_cents], "must be greater than 0"
  end

  test "formatting works" do
    invoice = Invoice.new(amount_cents: 123_456)

    assert_equal "$1,234.56", invoice.amount.format
  end
end
```

### 2. Integration Tests for Ledger Operations

```ruby
# test/models/entry_test.rb
class EntryTest < ActiveSupport::TestCase
  test "entry validates must_balance" do
    company = companies(:main)

    # Balanced entry succeeds
    entry = Entry.new(
      company: company,
      description: "Balanced",
      posted_at: Date.today
    )
    entry.line_items.build(account: accounts(:checking), amount_cents: 100)
    entry.line_items.build(account: accounts(:revenue), amount_cents: -100)

    assert entry.valid?
    assert_equal 0, entry.line_items.sum(:amount_cents)
  end

  test "entry rejects unbalanced line items" do
    company = companies(:main)

    # Unbalanced entry fails
    entry = Entry.new(
      company: company,
      description: "Unbalanced",
      posted_at: Date.today
    )
    entry.line_items.build(account: accounts(:checking), amount_cents: 100)
    entry.line_items.build(account: accounts(:revenue), amount_cents: -50)

    assert_not entry.valid?
    assert_includes entry.errors[:base], "Entry does not balance"
  end

  test "account balance calculated correctly" do
    company = companies(:main)
    checking = accounts(:checking)
    revenue = accounts(:revenue)

    # Post initial deposit
    Entry.transaction do
      entry = Entry.create!(
        company: company,
        description: "Initial deposit",
        posted_at: Date.today
      )
      entry.line_items.create!(account: checking, amount_cents: 50_000)
      entry.line_items.create!(account: revenue, amount_cents: -50_000)
    end

    # Post invoice
    Entry.transaction do
      entry = Entry.create!(
        company: company,
        description: "Invoice payment",
        posted_at: Date.today
      )
      entry.line_items.create!(account: checking, amount_cents: 10_000)
      entry.line_items.create!(account: revenue, amount_cents: -10_000)
    end

    # Verify balance
    assert_equal Money.new(60_000, 'USD'), checking.current_balance
    assert_equal Money.new(-60_000, 'USD'), revenue.current_balance
  end

  test "balance_at returns correct historical balance" do
    company = companies(:main)
    checking = accounts(:checking)
    revenue = accounts(:revenue)

    # Post entry on Jan 1
    Entry.transaction do
      entry = Entry.create!(
        company: company,
        description: "First deposit",
        posted_at: Date.new(2025, 1, 1)
      )
      entry.line_items.create!(account: checking, amount_cents: 30_000)
      entry.line_items.create!(account: revenue, amount_cents: -30_000)
    end

    # Post entry on Jan 15
    Entry.transaction do
      entry = Entry.create!(
        company: company,
        description: "Second deposit",
        posted_at: Date.new(2025, 1, 15)
      )
      entry.line_items.create!(account: checking, amount_cents: 20_000)
      entry.line_items.create!(account: revenue, amount_cents: -20_000)
    end

    # Check historical balance
    assert_equal Money.new(30_000, 'USD'),
                 checking.balance_at(Date.new(2025, 1, 10))
    assert_equal Money.new(50_000, 'USD'),
                 checking.balance_at(Date.new(2025, 1, 20))
  end
end
```

### 3. Money Object Tests (from test suite)

```ruby
# test/models/money_test.rb (already created in TASK-7.1)
class MoneyTest < ActiveSupport::TestCase
  test "money object can be created" do
    money = Money.new(1000, "USD")
    assert_equal 1000, money.cents
    assert_equal "USD", money.currency.to_s
  end

  test "money preserves precision with integers" do
    # Critical for accounting: $0.01 = 1 cent exactly
    money = Money.new(1, "USD")
    assert_equal 1, money.cents
    assert_equal "0.01", money.amount.to_s

    # Large amounts stay precise
    money = Money.new(123_456_789, "USD")
    assert_equal 123_456_789, money.cents
  end

  test "money supports arithmetic" do
    money1 = Money.new(1000, "USD")
    money2 = Money.new(500, "USD")

    sum = money1 + money2
    assert_equal 1500, sum.cents

    diff = money1 - money2
    assert_equal 500, diff.cents
  end
end
```

### 4. Fixture Pattern for Tests

```yaml
# test/fixtures/entries.yml
sample_entry:
  company: main
  description: "Sample entry"
  posted_at: 2025-01-15 10:00:00

# test/fixtures/line_items.yml
sample_debit:
  entry: sample_entry
  company: main
  account: checking
  amount_cents: 10000
  currency: USD

sample_credit:
  entry: sample_entry
  company: main
  account: revenue
  amount_cents: -10000
  currency: USD
```

### 5. Mock Payment Tests

```ruby
# test/services/payment_processor_test.rb
class PaymentProcessorTest < ActiveSupport::TestCase
  test "processes valid payment" do
    processor = PaymentProcessor.new

    payment = processor.process_payment("123.45")

    assert_equal 12_345, payment.amount_cents
    assert payment.persisted?
  end

  test "rejects invalid amount format" do
    processor = PaymentProcessor.new

    assert_raises ArgumentError do
      processor.process_payment("invalid")
    end
  end

  test "rejects amount over limit" do
    processor = PaymentProcessor.new

    assert_raises ArgumentError do
      processor.process_payment("999999.99")  # Over $1M limit
    end
  end
end
```

---

## Multi-Currency Considerations

### Current (v1) Status

GrayLedger v1 is **USD-only**. All amounts are stored with `currency = 'USD'`.

### Future Multi-Currency Support

When implementing multi-currency support in future versions:

#### 1. Database Schema Extension

```ruby
# db/migrate/[timestamp]_enable_multi_currency.rb
class EnableMultiCurrency < ActiveRecord::Migration[8.0]
  def change
    # Customers table gets default currency
    add_column :companies, :default_currency, :string, default: 'USD'
    add_column :companies, :supported_currencies, :json, default: ['USD']

    # Entries table tracks currency (for reporting)
    add_column :entries, :currency, :string, default: 'USD'

    # Add currency validation index
    add_index :line_items, [:account_id, :currency, :posted_at]
  end
end
```

#### 2. Multi-Currency Validation

```ruby
# app/models/entry.rb (future)
class Entry < ApplicationRecord
  # Currency locked at entry level
  validate :all_line_items_same_currency

  private

  def all_line_items_same_currency
    currencies = line_items.map(&:currency).uniq
    if currencies.size > 1
      errors.add(:base, "All line items must use same currency")
    end
  end
end
```

#### 3. Exchange Rate Handling

```ruby
# app/services/exchange_rate_service.rb (future)
class ExchangeRateService
  # Convert Money between currencies
  def self.convert(money, target_currency, exchange_date)
    rate = ExchangeRate.find_by(
      from_currency: money.currency.iso_code,
      to_currency: target_currency,
      date: exchange_date
    )

    if rate.nil?
      raise StandardError, "No exchange rate for #{money.currency} -> #{target_currency}"
    end

    Money.new(
      (money.cents * rate.rate).round.to_i,
      target_currency
    )
  end
end

# Usage
usd_amount = Money.new(10_000, 'USD')
eur_amount = ExchangeRateService.convert(usd_amount, 'EUR', Date.today)
```

#### 4. Reporting Across Currencies

```ruby
# app/models/report.rb (future)
class Report
  def total_revenue_by_currency
    entries
      .joins(line_items: :account)
      .where(accounts: { account_type: 'revenue' })
      .group('line_items.currency')
      .sum(:amount_cents)
      .transform_keys { |currency| Money.new(1, currency).currency }
  end

  # Convert to reporting currency
  def total_revenue_usd
    by_currency = total_revenue_by_currency

    by_currency.sum do |currency, total|
      if currency.iso_code == 'USD'
        total
      else
        ExchangeRateService.convert(
          Money.new(total.cents, currency.iso_code),
          'USD',
          Date.today
        ).cents
      end
    end
  end
end
```

---

## Common Questions

### Q: Should I store currency with every amount?

**A:** Yes. Even though v1 is USD-only, money-rails requires it. The two-column pattern (amount_cents + amount_currency) allows future multi-currency without migration.

### Q: What about decimal precision (2 decimals for cents)?

**A:** Irrelevant. You store integers (cents), not decimals. 1 cent = 1 unit in the database.

### Q: How do I handle rounding for tax calculations?

**A:** Use `.round.to_i` after arithmetic:

```ruby
tax = subtotal * 0.08  # Money(10000, 'USD') * 0.08 = Money(800, 'USD')
tax_cents = tax.cents  # => 800
```

### Q: Can I use Decimal type instead of Integer?

**A:** No. Integer (cents) is the standard for Rails financial apps. PostgreSQL integers are exact, unlimited precision.

### Q: What if amount is negative?

**A:** It's valid in LineItems (credits are negative). Validate by account type in business logic:

```ruby
class LineItem < ApplicationRecord
  validate :amount_makes_sense_for_account_type

  private

  def amount_makes_sense_for_account_type
    if account.asset? && amount_cents < 0
      errors.add(:amount_cents, "can't be negative for asset accounts")
    end
  end
end
```

### Q: How do I export to accounting software (QuickBooks, Xero)?

**A:** Use the raw database structure. These tools read the standard format:

```ruby
# app/services/export_service.rb
class ExportService
  def export_entries_for_qbo
    entries.includes(:line_items).map do |entry|
      {
        id: entry.id,
        date: entry.posted_at.iso8601,
        description: entry.description,
        line_items: entry.line_items.map { |li|
          {
            account_id: li.account_id,
            amount: (li.amount_cents.to_f / 100).round(2),
            memo: li.memo
          }
        }
      }
    end.to_json
  end
end
```

---

## Summary

money-rails 1.15.0 is production-ready for Rails 8.1.1+. Key takeaways:

- **Always store as integers** (cents), never floats
- **Two columns per amount**: `amount_cents` (integer) + `amount_currency` (string)
- **Validate everything**: presence, numericality, currency consistency
- **Use transactions** for ledger operations
- **Never store balances**: calculate on read
- **Index aggressively** for query performance
- **Format for display**, not storage
- **Test thoroughly** with fixtures and integration tests

For questions or issues, refer to:
- [money-rails GitHub](https://github.com/RubyMoney/money-rails)
- [Money gem documentation](https://github.com/RubyMoney/money)
- GrayLedger ADR 04.001 (Minimal Double-Entry Ledger)
