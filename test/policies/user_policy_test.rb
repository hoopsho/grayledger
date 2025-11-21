require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
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

  setup do
    # Create mock user objects for testing Pundit policies
    @regular_user = MockUser.new(1, "user@example.com", "user")
    @superuser = MockUser.new(2, "admin@grayledger.io", "user")
    @other_user = MockUser.new(3, "other@example.com", "user")
  end

  test "user can view their own profile" do
    policy = UserPolicy.new(@regular_user, @regular_user)
    assert policy.show?
  end

  test "user cannot view another user's profile" do
    policy = UserPolicy.new(@regular_user, @other_user)
    assert_not policy.show?
  end

  test "superuser can view any user's profile" do
    policy = UserPolicy.new(@superuser, @other_user)
    assert policy.show?
  end

  test "user can update their own profile" do
    policy = UserPolicy.new(@regular_user, @regular_user)
    assert policy.update?
  end

  test "user cannot update another user's profile" do
    policy = UserPolicy.new(@regular_user, @other_user)
    assert_not policy.update?
  end

  test "superuser can update any user's profile" do
    policy = UserPolicy.new(@superuser, @other_user)
    assert policy.update?
  end

  test "user cannot destroy their own account" do
    policy = UserPolicy.new(@regular_user, @regular_user)
    assert_not policy.destroy?
  end

  test "superuser can destroy any user" do
    policy = UserPolicy.new(@superuser, @other_user)
    assert policy.destroy?
  end

  test "regular user cannot list users" do
    policy = UserPolicy.new(@regular_user, User)
    assert_not policy.index?
  end

  test "superuser can list all users" do
    policy = UserPolicy.new(@superuser, User)
    assert policy.index?
  end

  test "regular user cannot create users" do
    policy = UserPolicy.new(@regular_user, User)
    assert_not policy.create?
  end

  test "superuser can create users" do
    policy = UserPolicy.new(@superuser, User)
    assert policy.create?
  end
end
