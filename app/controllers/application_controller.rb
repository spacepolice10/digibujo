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

  # Common bullet params handling shared by BulletsController and
  # MonthlyBuckets::BulletsController. Each bulletable type declares
  # its permitted attributes via Bulletable.permitted_bullet_attributes.

  def permitted_bullet_attributes
    bulletable_class.permitted_bullet_attributes
  end

  BULLETABLE_CLASSES = {
  "Task"  => Task,
  "Note"  => Note,
  "Event" => Event,
  "Title" => Title
}.freeze

def bulletable_class
  BULLETABLE_CLASSES[params.dig(:bullet, :bulletable_type)] || BULLETABLE_CLASSES[Bullet::Composer.default_type]
end

  # accepts_nested_attributes_for :bulletable needs both bulletable_type and
  # bulletable_attributes present, even when the form submits neither.
  def ensure_bulletable_defaults!(permitted)
    type_name = bulletable_class.name
    permitted[:bulletable_type] = type_name if permitted[:bulletable_type].blank?
    permitted[:bulletable_attributes] = {} if permitted[:bulletable_attributes].blank?
    permitted
  end
end
