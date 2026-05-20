# frozen_string_literal: true

# Records append-only BulletActivity rows for meaningful bullet and task updates.
#
# Edit detection skips intent-only saves (collect, schedule, postpone, pin). Action Text
# body changes are tracked via `BulletActivityRichTextTracking` on +ActionText::RichText+.
#
# Bulk +update_all+ (e.g. sweep) bypasses callbacks and does not create ARCHIVED rows.
module TracksBulletActivity
  extend ActiveSupport::Concern

  ORGANIZING_CHANGE_KEY_SETS = [
    %w[triaged_at],
    %w[bucket_id],
    %w[bucket_id triaged_at],
    %w[pinned],
    %w[scheduled_on triaged_at]
  ].map(&:sort).map(&:freeze).freeze

  included do |base|
    if base == Bullet
      after_commit :record_activities_for_bullet_update, on: :update
    elsif base == Task
      after_commit :record_activities_for_task_update, on: :update
    end
  end

  private

  def record_activities_for_bullet_update
    changes = previous_changes
    return if changes.blank?

    if archived_turned_true_for_activity?(changes)
      BulletActivity.record(user: user, bullet: self, action: BulletActivity::ARCHIVED)
      return
    end

    return if organizing_only_bullet_changes_for_activity?(changes)
    return unless bullet_activity_column_edit_keys(changes).any?

    BulletActivity.suppress_rich_text_edit_for(id)
    BulletActivity.record(user: user, bullet: self, action: BulletActivity::EDITED)
  end

  def record_activities_for_task_update
    changes = previous_changes
    return if changes.blank?
    return unless changes.key?('done')

    bullet = association(:bullet).reader
    return if bullet.blank?

    action = done ? BulletActivity::COMPLETED : BulletActivity::UNCOMPLETED
    BulletActivity.record(user: bullet.user, bullet: bullet, action: action)
  end

  def bullet_activity_column_edit_keys(changes)
    keys = normalized_bullet_change_keys_for_activity(changes)
    keys -= %w[archived archives_on] if unarchived_save_for_activity?(changes)
    keys
  end

  def archived_turned_true_for_activity?(changes)
    changes.key?('archived') && archived
  end

  def unarchived_save_for_activity?(changes)
    changes.key?('archived') && !archived
  end

  def organizing_only_bullet_changes_for_activity?(changes)
    keys = normalized_bullet_change_keys_for_activity(changes)
    return false if keys.empty?

    ORGANIZING_CHANGE_KEY_SETS.include?(keys.sort)
  end

  def normalized_bullet_change_keys_for_activity(changes)
    changes.keys.map(&:to_s) - %w[updated_at]
  end
end
