class User < ApplicationRecord
  # Use Rails 8 built-in authentication
  has_secure_password

  validates :email, presence: true, uniqueness: true
  validates :password, presence: true, if: :new_record?

  # Role support for Pundit policies
  # Note: Using string values instead of enum to avoid database access during initialization
  ROLES = ["user", "admin", "superuser"].freeze

  # Check if this is a platform staff member (superuser god-mode, ADR-14.001)
  def platform_staff?
    email&.ends_with?("@grayledger.io")
  end

  def superuser?
    (role == "superuser" || role == 2) || platform_staff?
  end
end
