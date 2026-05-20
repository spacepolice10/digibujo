# frozen_string_literal: true

# Fires EDITED when Action Text body changes. Skips when +BulletActivity.suppress_rich_text_edit_for+
# was set from a column-based EDITED on the same bullet in this commit batch.
module BulletActivityRichTextTracking
  extend ActiveSupport::Concern

  included do
    after_commit :bullet_activity_record_edited_after_body_update, on: :update
  end

  private

  def bullet_activity_record_edited_after_body_update
    return unless name == 'content' && record_type == 'Bullet'
    return unless previous_changes.key?('body')

    bullet = record
    return if BulletActivity.consume_suppress_rich_text_edit_for?(bullet.id)

    BulletActivity.record(user: bullet.user, bullet: bullet, action: BulletActivity::EDITED)
  end
end
