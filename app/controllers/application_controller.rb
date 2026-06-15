# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_variant
  around_action :set_timezone

  private

  def set_timezone(&)
    timezone_name = cookies[:timezone].presence
    timezone = timezone_name ? ActiveSupport::TimeZone[timezone_name] : nil

    Time.use_zone(timezone || Time.zone_default, &)
  end

  def set_variant
    request.variant = :mobile if request.user_agent&.match?(/Mobile|Android|iPhone/i)
  end
end
