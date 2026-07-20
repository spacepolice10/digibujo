# frozen_string_literal: true

class Activity < ApplicationRecord
  ACTIONS = %w[
    updated collected rescheduled completed uncompleted
    project_mentioned project_unmentioned
    pinned unpinned created destroyed archived unarchived
  ].freeze

  belongs_to :user
  belongs_to :subject, polymorphic: true, optional: true

  RETENTION_DAYS = 30

  validates :action, inclusion: { in: ACTIONS }
  validates :subject, presence: true

  def subject_name
    metadata['name'].presence || subject&.name || 'Unknown'
  end

  def subject_present?
    subject.present?
  end

  def from_date
    return if metadata['from_pops_on'].blank?

    metadata['from_pops_on'].to_date
  end

  def to_date
    return if metadata['to_pops_on'].blank?

    metadata['to_pops_on'].to_date
  end

  def destination_bucket
    return unless action == 'collected'

    user.buckets.find_by(id: metadata['bucket_id'])
  end
end
