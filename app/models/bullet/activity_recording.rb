# frozen_string_literal: true

module Bullet::ActivityRecording
  extend ActiveSupport::Concern
end

ActiveSupport.on_load(:action_text_rich_text) do
  after_save :record_bullet_body_updated_activity, if: :bulletable_body_update?

  private

  def bulletable_body_update?
    record.is_a?(Bulletable) && name == 'body' && saved_change_to_body? && !previously_new_record?
  end

  def record_bullet_body_updated_activity
    record.bullet&.record_activity!('updated')
  end
end
