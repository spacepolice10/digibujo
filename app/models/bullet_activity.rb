# frozen_string_literal: true

# Append-only record of user-visible bullet lifecycle actions.
class BulletActivity < ApplicationRecord
  EDITED = 'edited'
  ARCHIVED = 'archived'
  COMPLETED = 'completed'
  UNCOMPLETED = 'uncompleted'

  ACTIONS = [EDITED, ARCHIVED, COMPLETED, UNCOMPLETED].freeze

  ACTION_LABELS = {
    EDITED => 'Edited',
    ARCHIVED => 'Archived',
    COMPLETED => 'Completed',
    UNCOMPLETED => 'Uncompleted'
  }.freeze

  SUPPRESS_RICH_TEXT_EDIT_FOR = :bullet_activity_suppress_rich_text_edit_for

  belongs_to :user

  validates :action, inclusion: { in: ACTIONS }
  validates :bullet_id, presence: true

  def self.record(user:, bullet:, action:)
    create!(user_id: user.id, bullet_id: bullet.id, action: action)
  end

  def self.suppress_rich_text_edit_for(bullet_id)
    Thread.current[SUPPRESS_RICH_TEXT_EDIT_FOR] = bullet_id
  end

  def self.consume_suppress_rich_text_edit_for?(bullet_id)
    return false unless Thread.current[SUPPRESS_RICH_TEXT_EDIT_FOR] == bullet_id

    Thread.current[SUPPRESS_RICH_TEXT_EDIT_FOR] = nil
    true
  end

  def action_label
    ACTION_LABELS[action] || action.to_s.humanize
  end
end
