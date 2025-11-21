# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  # Scope for authorized user listing
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.superuser?
        @scope.all
      else
        @scope.where(id: user.id)
      end
    end
  end

  # Users can view their own profile, superusers can view anyone
  def show?
    user_is_record_owner? || user.superuser?
  end

  # Users can update their own profile, superusers can update anyone
  def update?
    user_is_record_owner? || user.superuser?
  end

  # Only superusers can destroy accounts (safety: regular users cannot delete their own)
  def destroy?
    user.superuser?
  end

  # Only superusers can list all users
  def index?
    user.superuser?
  end

  # Only superusers can create new users
  def create?
    user.superuser?
  end

  private

  def user_is_record_owner?
    user == @record
  end
end
