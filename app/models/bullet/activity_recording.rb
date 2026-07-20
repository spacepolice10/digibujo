# frozen_string_literal: true

module Bullet::ActivityRecording
  extend ActiveSupport::Concern
end

ActiveSupport.on_load(:action_text_rich_text) do
  after_save :record_note_body_updated_activity, if: :note_body_update?

  private

  def note_body_update?
    record.is_a?(Note) && name == 'body' && saved_change_to_body? && !previously_new_record?
  end

  def record_note_body_updated_activity
    record.bullet&.record_activity!('updated')
  end
end
