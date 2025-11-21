class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Default authorization failure handler for Pundit
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    action_name = exception.query.to_s.sub(/\?$/, '')

    # You can customize this behavior based on your needs
    # For HTML requests, redirect to root; for JSON requests, return 403
    if request.format.json?
      render json: { error: "You are not authorized to perform this action" }, status: :forbidden
    else
      redirect_to root_url, alert: "You are not authorized to perform this action"
    end
  end
end
