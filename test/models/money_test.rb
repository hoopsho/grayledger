require "test_helper"

class MoneyTest < ActiveSupport::TestCase
  test "money object can be created" do
    money = Money.new(1000, "USD")
    assert_equal 1000, money.cents
    assert_equal "USD", money.currency.to_s
  end

  test "money can be formatted" do
    money = Money.new(1000, "USD")
    assert_equal "$10.00", money.format
  end

  test "money supports arithmetic" do
    money1 = Money.new(1000, "USD")
    money2 = Money.new(500, "USD")

    sum = money1 + money2
    assert_equal 1500, sum.cents

    diff = money1 - money2
    assert_equal 500, diff.cents
  end

  test "money default currency is USD" do
    assert_equal "USD", Money.default_currency.to_s
  end

  test "money handles zero amounts" do
    money = Money.new(0, "USD")
    assert_equal 0, money.cents
    assert_equal "$0.00", money.format
  end

  test "money handles negative amounts" do
    money = Money.new(-1000, "USD")
    assert_equal(-1000, money.cents)
    # Money gem formats negative with sign after symbol: $-10.00
    assert_equal "$-10.00", money.format
  end

  test "money preserves precision with integers (no float errors)" do
    # Critical for accounting: $0.01 = 1 cent exactly
    money = Money.new(1, "USD")
    assert_equal 1, money.cents
    assert_equal "0.01", money.amount.to_s

    # Large amounts stay precise
    money = Money.new(123_456_789, "USD")
    assert_equal 123_456_789, money.cents
  end

  # Tests for monetize helper with InvoiceItem model
  test "monetize converts amount_cents to Money object" do
    item = InvoiceItem.new(amount_cents: 5000)
    assert_equal Money.new(5000, "USD"), item.amount
    assert_equal "$50.00", item.amount.format
  end

  test "monetize helper persists correctly" do
    item = InvoiceItem.create!(amount_cents: 7500)
    reloaded = InvoiceItem.find(item.id)

    assert_equal 7500, reloaded.amount_cents
    assert_equal "USD", reloaded.amount_currency
    assert_equal Money.new(7500, "USD"), reloaded.amount
    assert_equal "$75.00", reloaded.amount.format
  end

  test "money assignment through monetize works" do
    item = InvoiceItem.new
    item.amount = Money.new(2500, "USD")

    assert_equal 2500, item.amount_cents
    assert_equal "USD", item.amount_currency
    assert_equal Money.new(2500, "USD"), item.amount
  end

  test "monetize default currency is USD" do
    item = InvoiceItem.new(amount_cents: 1000)
    assert_equal "USD", item.amount_currency
  end
end
