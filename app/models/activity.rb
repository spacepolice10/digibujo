# frozen_string_literal: true

class Activity < ApplicationRecord
  SUBJECT_ACTIONS = {
    'Bullet' => %w[
      updated
      collected
      popped
      postponed
      migrated
      completed
      uncompleted
      project_mentioned
      project_unmentioned
      person_mentioned
      person_unmentioned
      acknowledged
      pinned
      unpinned
    ].freeze,
    'Bucket' => %w[created updated pinned unpinned destroyed].freeze,
    'Archive' => %w[archived unarchived].freeze
  }.freeze

  ACTION_ICON_MAPPINGS = {
    'updated' => 'pencil',
    'collected' => 'arrow-left',
    'popped' => 'arrow-up',
    'postponed' => 'arrow-up',
    'migrated' => 'arrow-up',
    'archived' => 'archive',
    'completed' => 'check',
    'uncompleted' => 'square',
    'project_mentioned' => 'hash',
    'project_unmentioned' => 'hash',
    'person_mentioned' => 'at',
    'person_unmentioned' => 'at',
    'created' => 'plus',
    'pinned' => 'pin',
    'unpinned' => 'pin',
    'unarchived' => 'archive',
    'acknowledged' => 'line-dashed',
    'destroyed' => 'trash'
  }.freeze

  belongs_to :user
  belongs_to :subject, polymorphic: true, optional: true

  RETENTION_DAYS = 30

  validates :action, inclusion: { in: ->(activity) { SUBJECT_ACTIONS.fetch(activity.subject_type) } }
  validates :subject, presence: true

  def self.sweep
    where(created_at: ...RETENTION_DAYS.days.ago).delete_all
  end

  def action_name
    action.humanize
  end

  def icon
    ACTION_ICON_MAPPINGS.fetch(action)
  end

  def icon_mask
    "var(--icon-#{icon})"
  end

  def colour
    Colourable.colour_variable_of(subject_colour)
  end

  def type_name
    case subject_type
    when 'Bullet'
      subject&.bulletable_type&.downcase
    when 'Bucket'
      (metadata['bucketable_type'].presence || subject&.bucketable_type)&.downcase
    when 'Archive'
      (metadata['bulletable_type'].presence || metadata['bucketable_type'].presence || metadata['archivable_type'])&.downcase
    end
  end

  def subject_name
    metadata['name'].presence || subject&.name || 'Unknown'
  end

  def detail
    "#{action_name} — #{subject_name}"
  end

  def bullet_subject?
    subject_type == 'Bullet'
  end

  def subject_present?
    subject.present?
  end

  def subject_history
    return Activity.none unless subject

    subject.activities.where.not(id: id).order(created_at: :desc).limit(30)
  end

  def summary
    case action
    when 'postponed', 'popped' then postponed_summary
    when 'collected' then collected_summary
    when 'completed' then completed_summary
    when 'archived' then archived_summary
    when 'acknowledged' then acknowledged_summary
    else
      detail
    end
  end

  def from_day
    migration_date(metadata['from_pops_on'])
  end

  def to_day
    migration_date(metadata['to_pops_on'])
  end

  def destination_bucket
    return unless action == 'collected'

    user.buckets.find_by(id: metadata['bucket_id'])
  end

  def bucket_label
    metadata['bucket_name'].presence || destination_bucket&.name || 'a collection'
  end

  def from_day_name
    migration_date_name(metadata['from_pops_on'])
  end

  def to_day_name
    migration_date_name(metadata['to_pops_on'])
  end

  private

  def subject_colour
    metadata['colour'].presence || subject&.colour
  end

  def postponed_summary
    from = migration_date_name(metadata['from_pops_on'])
    to = migration_date_name(metadata['to_pops_on'])

    if from && to
      "Moved from #{from} to #{to}"
    elsif to
      "Scheduled for #{to}"
    else
      'Parked for sometime'
    end
  end

  def collected_summary
    "Moved into #{bucket_label}"
  end

  def completed_summary
    date = migration_date_name(metadata['pops_on'])
    date ? "Completed on #{date}" : 'Completed'
  end

  def archived_summary
    date = migration_date_name(metadata['pops_on'])
    date ? "Archived — removed from #{date}" : 'Archived — removed from the daily log'
  end

  def acknowledged_summary
    date = migration_date_name(metadata['pops_on'])
    date ? "Reviewed — kept on #{date}" : 'Reviewed — no changes during review'
  end

  def migration_date(value)
    return if value.blank?

    value.to_date
  end

  def migration_date_name(value)
    migration_date(value)&.strftime('%a, %b %-d')
  end
end
