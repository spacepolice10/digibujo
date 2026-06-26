# frozen_string_literal: true

class Activity < ApplicationRecord
  SUBJECT_ACTIONS = {
    'Bullet' => %w[
      updated
      collected
      popped
      archived
      unarchived
      completed
      uncompleted
      project_mentioned
      project_unmentioned
      person_mentioned
      person_unmentioned
      acknowledged
    ].freeze,
    'Bucket' => %w[created updated pinned unpinned archived unarchived].freeze
  }.freeze

  ACTION_ICON_MAPPINGS = {
    'updated' => 'pencil',
    'collected' => 'arrow-left',
    'popped' => 'arrow-up',
    'archived' => 'archive',
    'completed' => 'check',
    'uncompleted' => 'square',
    'project_mentioned' => 'tag',
    'project_unmentioned' => 'tag',
    'person_mentioned' => 'face',
    'person_unmentioned' => 'face',
    'created' => 'plus',
    'pinned' => 'pin',
    'unpinned' => 'pin',
    'unarchived' => 'archive',
    'acknowledged' => 'line-dashed'
  }.freeze

  belongs_to :user
  belongs_to :subject, polymorphic: true

  validates :action, inclusion: { in: ->(activity) { SUBJECT_ACTIONS.fetch(activity.subject_type) } }
  validates :subject, presence: true

  def action_name
    action.humanize
  end

  def icon_mask
    "var(--icon-#{ACTION_ICON_MAPPINGS.fetch(action)})"
  end

end
