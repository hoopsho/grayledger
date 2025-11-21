require "test_helper"

class PostPolicyTest < ActiveSupport::TestCase
  # Mock user object for testing Pundit policies without database
  class MockUser
    attr_reader :id, :email, :role

    def initialize(id, email, role)
      @id = id
      @email = email
      @role = role
    end

    def platform_staff?
      @email&.ends_with?("@grayledger.io")
    end

    def superuser?
      (@role == "superuser") || platform_staff?
    end

    def ==(other)
      other.is_a?(MockUser) && @id == other.id
    end
  end

  # Mock post object for testing
  class MockPost
    attr_reader :id, :user_id

    def initialize(id, user_id)
      @id = id
      @user_id = user_id
    end
  end

  setup do
    # Create mock user objects
    @regular_user = MockUser.new(1, "user@example.com", "user")
    @other_user = MockUser.new(2, "other@example.com", "user")
    @superuser = MockUser.new(3, "admin@grayledger.io", "user")

    # Create mock post objects
    @regular_user_post = MockPost.new(1, @regular_user.id)
    @other_user_post = MockPost.new(2, @other_user.id)
  end

  # Show tests
  test "user can view their own post" do
    policy = PostPolicy.new(@regular_user, @regular_user_post)
    assert policy.show?
  end

  test "user cannot view another user's post" do
    policy = PostPolicy.new(@regular_user, @other_user_post)
    assert_not policy.show?
  end

  test "superuser can view any post" do
    policy = PostPolicy.new(@superuser, @other_user_post)
    assert policy.show?
  end

  # Create tests
  test "regular user can create posts" do
    policy = PostPolicy.new(@regular_user, Post)
    assert policy.create?
  end

  test "superuser can create posts" do
    policy = PostPolicy.new(@superuser, Post)
    assert policy.create?
  end

  # Update tests
  test "user can update their own post" do
    policy = PostPolicy.new(@regular_user, @regular_user_post)
    assert policy.update?
  end

  test "user cannot update another user's post" do
    policy = PostPolicy.new(@regular_user, @other_user_post)
    assert_not policy.update?
  end

  test "superuser can update any post" do
    policy = PostPolicy.new(@superuser, @other_user_post)
    assert policy.update?
  end

  # Destroy tests
  test "user can destroy their own post" do
    policy = PostPolicy.new(@regular_user, @regular_user_post)
    assert policy.destroy?
  end

  test "user cannot destroy another user's post" do
    policy = PostPolicy.new(@regular_user, @other_user_post)
    assert_not policy.destroy?
  end

  test "superuser can destroy any post" do
    policy = PostPolicy.new(@superuser, @other_user_post)
    assert policy.destroy?
  end

  # Index tests
  test "regular user can see post index" do
    policy = PostPolicy.new(@regular_user, Post)
    assert policy.index?
  end

  test "superuser can see post index" do
    policy = PostPolicy.new(@superuser, Post)
    assert policy.index?
  end
end
