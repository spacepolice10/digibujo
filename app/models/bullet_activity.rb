# frozen_string_literal: true

class BulletActivity < ApplicationRecord
  ACTIONS = %w[
    updated
    postponed
    collected
    popped
    archived
    completed
    uncompleted
    edited
  ].freeze

  belongs_to :user

  validates :action, inclusion: { in: ACTIONS }
  validates :bullet_id, presence: true

  def action_name
    action.humanize
  end
end
