# frozen_string_literal: true

class PostPolicy < ApplicationPolicy
  # Scope for authorized post listing
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.superuser?
        @scope.all
      else
        @scope.where(user: user)
      end
    end
  end

  # Regular users can view their own posts, superusers can view all
  def show?
    user_is_record_author? || user.superuser?
  end

  # Users can create posts
  def create?
    true
  end

  # Users can update their own posts, superusers can update any
  def update?
    user_is_record_author? || user.superuser?
  end

  # Users can delete their own posts, superusers can delete any
  def destroy?
    user_is_record_author? || user.superuser?
  end

  # Regular users can only list their own posts, superusers see all
  def index?
    true
  end

  private

  def user_is_record_author?
    @record.user_id == user.id
  end
end
