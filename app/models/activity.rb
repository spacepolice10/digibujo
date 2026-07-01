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

  def self.day_heading_for(date)
    case date
    when Date.current then 'Today'
    when Date.yesterday then 'Yesterday'
    else date.strftime('%a, %b %-d')
    end
  end

  def detail
    case action
    when 'popped' then popped_detail
    when 'collected' then collected_detail
    when 'completed' then completed_detail
    when 'archived' then archived_detail
    when 'acknowledged' then acknowledged_detail
    when 'pinned', 'unpinned' then bucketable_detail
    when 'created', 'updated', 'unarchived' then bucketable_detail if subject_type == 'Bucket'
    end
  end

  private

  def popped_detail
    from = migration_date_name(metadata['from_pops_on'])
    to = migration_date_name(metadata['to_pops_on'] || subject&.try(:pops_on))

    if from && to
      "Rescheduled from #{from} to #{to}"
    elsif to
      "Scheduled for #{to}"
    end
  end

  def collected_detail
    bucket_name = metadata['bucket_name'].presence
    bucket_name ? "Moved into #{bucket_name}" : nil
  end

  def completed_detail
    date = migration_date_name(metadata['pops_on'] || subject&.try(:pops_on))
    date ? "Completed on #{date}" : 'Completed'
  end

  def archived_detail
    if subject_type == 'Bucket'
      bucketable_detail
    else
      date = migration_date_name(metadata['pops_on'] || subject&.try(:pops_on))
      date ? "Removed from #{date}" : 'Removed from the daily log'
    end
  end

  def acknowledged_detail
    date = migration_date_name(metadata['pops_on'] || subject&.try(:pops_on))
    date ? "Reviewed — kept on #{date}" : 'Reviewed during migration'
  end

  def bucketable_detail
    bucketable_type = metadata['bucketable_type'].presence
    bucketable_type ? "#{action_name} — #{bucketable_type.titleize}" : nil
  end

  def migration_date_name(value)
    return if value.blank?

    value.to_date.strftime('%a, %b %-d')
  end
end
