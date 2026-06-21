# frozen_string_literal: true

class MonthlyBucket < ApplicationRecord
  include Bucketable, Periodable
  belongs_to :user
  belongs_to :future_bucket

  validates :future_bucket, presence: true
  validates :period_from, presence: true, uniqueness: { scope: :user_id }
  validate :period_is_full_calendar_month

  def self.current(user, date = Date.current)
    user.monthly_buckets.find_by(period_from: date.beginning_of_month)
  end

  def covers_date?(date)
    period_from == date.to_date.beginning_of_month
  end

  before_validation :set_default_period, :snap_period_from

  private

  def set_default_period
    return if period_from.present? || period_to.present?

    defaults = self.class.default_period
    self.period_from = defaults[:period_from]
    self.period_to = defaults[:period_to]
  end

  def snap_period_from
    self.period_from = period_from.beginning_of_month if period_from.present?
  end

  def period_is_full_calendar_month
    return unless period_from.present? && period_to.present?
    return if period_to == period_from.end_of_month

    errors.add(:base, 'Spread must cover a full calendar month')
  end
end
