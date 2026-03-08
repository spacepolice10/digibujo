class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_variant

  private

  def set_variant
    request.variant = :mobile if request.user_agent&.match?(/Mobile|Android|iPhone/i)
  end
end
