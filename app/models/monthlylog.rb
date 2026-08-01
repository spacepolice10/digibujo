# frozen_string_literal: true

class Monthlylog < ApplicationRecord
  include Bucketable

  belongs_to :user

  validates :period_from, presence: true, uniqueness: { scope: :user_id }

  before_validation :normalize_period

  scope :covering, lambda { |date = Date.current|
    day = date.to_date
    where(period_from: ..day, period_to: day..)
  }

  def self.provision!(user, date: Date.current)
    month = date.to_date.beginning_of_month
    if (existing = user.monthlylogs.covering(month).take)
      return existing if existing.bucket

      user.buckets.create!(
        bucketable: existing,
        name: month.strftime('%B %Y'),
        icon: 'calendar'
      )
      return existing.reload
    end

    record = user.monthlylogs.create!(period_from: month)
    user.buckets.create!(
      bucketable: record,
      name: month.strftime('%B %Y'),
      icon: 'calendar'
    )
    record.bucket.record_activity!(
      'created',
      metadata: { 'bucketable_type' => 'Monthlylog' }
    )
    record.reload
  end

  def spread_days
    return [] if period_from.blank?

    (period_from.to_date..period_to.to_date).to_a
  end

  private

  def normalize_period
    return if period_from.blank?

    self.period_from = period_from.to_date.beginning_of_month
    self.period_to = period_from.end_of_month
  end
end
