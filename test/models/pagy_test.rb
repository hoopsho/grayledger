require "test_helper"

class PagyTest < ActiveSupport::TestCase
  # Test Pagy configuration and basic pagination
  # Pagy::Backend is included in ApplicationController
  # We focus on testing Pagy's core functionality

  test "Pagy is installed and loaded" do
    assert defined?(Pagy), "Pagy should be available"
    assert defined?(Pagy::Backend), "Pagy::Backend should be available"
  end

  test "Pagy can be used in a controller" do
    controller = ApplicationController.new
    assert controller.respond_to?(:pagy, true), "Controller should have pagy method (private or public)"
  end

  test "Pagy provides core pagination functionality" do
    # Test Pagy directly without controller context
    collection = (1..100).to_a

    # Create a pagy object directly with default items per page
    # Pagy defaults to 20 items per page
    pagy = Pagy.new(count: collection.count)

    # Verify basic pagination
    assert_equal 20, pagy.limit, "Pagy default limit (items per page) should be 20"
    assert_equal 5, pagy.pages, "100 items / 20 per page = 5 pages"
    assert_equal 100, pagy.count, "Total count should be 100"
    assert_equal 1, pagy.page, "Current page should be 1"
    assert_equal 0, pagy.offset, "Page 1 offset should be 0"
  end

  test "Pagy calculates offset correctly" do
    collection = (1..100).to_a

    # Test different pages
    pagy1 = Pagy.new(count: collection.count, page: 1)
    assert_equal 0, pagy1.offset, "Page 1 offset should be 0"

    pagy2 = Pagy.new(count: collection.count, page: 2)
    assert_equal 20, pagy2.offset, "Page 2 offset should be 20 (1 * 20)"

    pagy3 = Pagy.new(count: collection.count, page: 3)
    assert_equal 40, pagy3.offset, "Page 3 offset should be 40 (2 * 20)"
  end

  test "Pagy provides next page navigation" do
    collection = (1..100).to_a

    pagy = Pagy.new(count: collection.count, page: 1)

    # Test navigation helpers
    assert_nil pagy.prev, "No previous page from first page"
    assert_equal 2, pagy.next, "Next page should be 2"
  end
end
