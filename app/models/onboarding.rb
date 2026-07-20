# frozen_string_literal: true

class Onboarding
  include ActiveModel::Validations, ActiveModel::Model

  FUTURE_NAME = 'Future Log'
  FUTURE_ICON = 'calendar'
  FUTURE_COLOUR = 'gold'
  LOOSE_NOTES_NAME = 'Loose Notes'
  DAYLOG_NAME = 'Daylog'
  DAYLOG_ICON = 'calendar'

  attr_accessor :user

  validates :user, presence: true

  def complete
    return false unless valid?

    ActiveRecord::Base.transaction do
      ensure_loose_notes!
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  # Ensures a single Daylog bucket exists and returns it.
  def self.ensure_daylog_bucket!(user, _date = Date.current)
    if (existing = user.daylog)
      return existing.bucket if existing.bucket

      user.buckets.create!(bucketable: existing, name: DAYLOG_NAME, icon: DAYLOG_ICON)
      return existing.reload.bucket
    end

    record = user.create_daylog!
    user.buckets.create!(bucketable: record, name: DAYLOG_NAME, icon: DAYLOG_ICON)
  end

  private

  def ensure_loose_notes!
    existing = user.buckets.find_by(bucketable_type: 'Collection', name: LOOSE_NOTES_NAME.downcase)
    return if existing.present?

    collection = Collection.create!
    user.buckets.create!(bucketable: collection, name: LOOSE_NOTES_NAME)
  end
end
