require "test_helper"

class PagyTest < ActiveSupport::TestCase
  # Test Pagy configuration and basic pagination
  # Pagy::Backend is included in ApplicationController
  # We can test the configuration directly

  test "Pagy is installed and loaded" do
    assert defined?(Pagy), "Pagy should be available"
    assert defined?(Pagy::Backend), "Pagy::Backend should be available"
  end

  test "Pagy can be used in a controller" do
    controller = ApplicationController.new
    assert controller.respond_to?(:pagy), "Controller should have pagy method"
  end

  test "Pagy pagination with collection" do
    # Create a mock controller instance to test pagy
    controller = ApplicationController.new

    # Simulate a collection
    collection = (1..100).to_a

    # Test pagination with default settings
    pagy, items = controller.pagy(collection.to_enum)

    # Verify basic pagination
    assert_equal 25, pagy.size, "Pagy default size should be 25"
    assert_equal 4, pagy.pages, "100 items / 25 per page = 4 pages"
    assert_equal 100, pagy.count, "Total count should be 100"
    assert_equal 1, pagy.page, "Current page should be 1"
    assert_equal 25, items.count, "First page should have 25 items"
  end

  test "Pagy respects custom page size" do
    controller = ApplicationController.new
    collection = (1..100).to_a

    # Test with custom size
    pagy, items = controller.pagy(collection.to_enum, size: 10)

    assert_equal 10, pagy.size, "Custom size should be 10"
    assert_equal 10, pagy.pages, "100 items / 10 per page = 10 pages"
    assert_equal 10, items.count, "Page should have 10 items"
  end

  test "Pagy calculates offset correctly" do
    controller = ApplicationController.new
    collection = (1..100).to_a

    # Test different pages
    pagy1, = controller.pagy(collection.to_enum, page: 1)
    assert_equal 0, pagy1.offset, "Page 1 offset should be 0"

    pagy2, = controller.pagy(collection.to_enum, page: 2)
    assert_equal 25, pagy2.offset, "Page 2 offset should be 25"

    pagy3, = controller.pagy(collection.to_enum, page: 3)
    assert_equal 50, pagy3.offset, "Page 3 offset should be 50"
  end

  test "Pagy works with ActiveRecord-like collections" do
    controller = ApplicationController.new

    # Create items list that acts like a scope
    items = [
      OpenStruct.new(id: 1, name: "Item 1"),
      OpenStruct.new(id: 2, name: "Item 2"),
      OpenStruct.new(id: 3, name: "Item 3")
    ]

    pagy, paginated_items = controller.pagy(items.to_enum, size: 2)

    assert_equal 2, pagy.size, "Size should be 2"
    assert_equal 2, paginated_items.count, "Should have 2 items on page 1"
  end

  test "Pagy provides navigation metadata" do
    controller = ApplicationController.new
    collection = (1..100).to_a

    pagy, = controller.pagy(collection.to_enum)

    # Test navigation helpers
    assert pagy.first?, "First page should be identified"
    assert_not pagy.last?, "First page is not the last page"
    assert_equal 1, pagy.prev, "No previous page from first page (returns 1)"
    assert_equal 2, pagy.next, "Next page should be 2"
  end
end
