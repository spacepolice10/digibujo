# frozen_string_literal: true

# Shared behaviour for bulletables that store body as a plain text column
# (Task, Event, Voice). Note uses ActionText instead.
module PlainBodyBulletable
  extend ActiveSupport::Concern

  included do
    after_update :record_plain_body_updated_activity, if: :should_record_plain_body_update?
  end

  def name
    body.to_s.strip.presence || 'Untitled'
  end

  def excerpt
    body.to_s.strip.presence || 'Untitled'
  end

  private

  def should_record_plain_body_update?
    saved_change_to_body? && !previously_new_record?
  end

  def record_plain_body_updated_activity
    return unless bullet&.persisted?

    bullet.record_activity!('updated')
  end
end
