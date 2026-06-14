# frozen_string_literal: true

class BulletActivity < ApplicationRecord
  ACTIONS = %w[
    updated
    collected
    popped
    archived
    completed
    uncompleted
    edited
    project_tagged
    project_untagged
    person_tagged
    person_untagged
  ].freeze

  belongs_to :user
  belongs_to :bullet

  validates :action, inclusion: { in: ACTIONS }
  validates :bullet, presence: true

  def action_name
    action.humanize
  end
end
