# frozen_string_literal: true

class Activity < ApplicationRecord
  SUBJECT_ACTIONS = {
    'Bullet' => %w[
      updated
      collected
      popped
      archived
      completed
      uncompleted
      project_tagged
      project_untagged
      person_tagged
      person_untagged
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
    'project_tagged' => 'tag',
    'project_untagged' => 'tag',
    'person_tagged' => 'face',
    'person_untagged' => 'face',
    'created' => 'plus',
    'pinned' => 'pin',
    'unpinned' => 'pin',
    'unarchived' => 'archive'
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

  def migration_kind
    metadata['kind']
  end
end
