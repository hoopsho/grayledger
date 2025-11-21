# encoding : utf-8

MoneyRails.configure do |config|

  # Set the default currency to USD (required for accounting application)
  # All monetary values default to USD unless explicitly specified
  #
  config.default_currency = :usd

  # To handle the inclusion of validations for monetized fields
  # The default value is true - enables validates_numericality_of and validates_presence_of
  # for monetized attributes automatically
  #
  config.include_validations = true

  # Rounding mode for safe monetary calculations
  # ROUND_HALF_EVEN (banker's rounding) is the default and provides the most
  # stable financial calculations by minimizing cumulative rounding bias
  # This is critical for double-entry accounting where balances must reconcile
  # exactly to zero (no penny rounding errors)
  #
  # Other safe options:
  # - BigDecimal::ROUND_UP: Always rounds up (suitable for invoice totals)
  # - BigDecimal::ROUND_DOWN: Always rounds down (avoid for accounting)
  # - BigDecimal::ROUND_HALF_UP: Traditional 0.5 rounds up (good for display)
  #
  config.rounding_mode = BigDecimal::ROUND_HALF_EVEN

  # Default ActiveRecord migration configuration values for columns
  # These settings define how monetized fields are stored in the database:
  # - prefix/postfix: Column naming convention (e.g., "amount_cents")
  # - type: Always use :integer for cents to avoid floating-point errors
  # - null: false ensures all amounts are recorded (no NULL amounts)
  # - default: 0 provides sensible fallback
  #
  config.amount_column = {
    prefix: '',
    postfix: '_cents',
    column_name: nil,
    type: :integer,      # Critical: Store as integers, never floats
    present: true,
    null: false,         # Enforce data integrity
    default: 0
  }

  config.currency_column = {
    prefix: '',
    postfix: '_currency',
    column_name: nil,
    type: :string,
    present: true,
    null: false,
    default: 'USD'
  }

  # If you would like to use I18n localization (formatting depends on the locale):
  # Recommended for displaying amounts to users in their locale
  # Example:
  # I18n.locale = :en
  # Money.new(10_000_00, 'USD').format # => $10,000.00
  #
  # config.locale_backend = :i18n

  # For per-currency localization (formatting depends only on currency):
  # config.locale_backend = :currency

  # Using default locale backend (no localization, uses currency symbol defaults)
  config.locale_backend = nil

  # Set default raise_error_on_money_parsing option
  # When true, raises error if assigning different currency than field's currency
  # Keep false for flexibility, but validate at application level
  #
  config.raise_error_on_money_parsing = false
end
