# frozen_string_literal: true

class MonthlyBucket < ApplicationRecord
  include Bucketable
  belongs_to :user
  belongs_to :future_bucket

  validates :future_bucket, presence: true
  validates :period_from, presence: true, uniqueness: { scope: :user_id }
  validates :period_to, presence: true
  validate :period_from_must_be_selectable, on: :create
  validate :period_must_cover_full_calendar_month

  def self.current(user, date = Date.current)
    user.monthly_buckets.find_by(period_from: date.beginning_of_month)
  end

  def self.period_for(date)
    month_start = date.to_date.beginning_of_month
    { period_from: month_start, period_to: month_start.end_of_month }
  end

  def self.default_period
    period_for(Date.current)
  end

  def self.selectable_months(from: Date.current)
    (0..5).map { |i| from.beginning_of_month + i.months }
  end

  def covers_date?(date)
    period_from == date.to_date.beginning_of_month
  end

  def period?
    period_from.present? && period_to.present?
  end

  def period_days
    period? ? (period_from..period_to) : nil
  end

  private

  def period_from_must_be_selectable
    return if period_from.blank?
    return if self.class.selectable_months.include?(period_from)

    errors.add(:period_from, 'must be within the next six months')
  end

  def period_must_cover_full_calendar_month
    return if period_from.blank? || period_to.blank?
    return if period_from == period_from.beginning_of_month && period_to == period_from.end_of_month

    errors.add(:period_to, 'must be the last day of the spread month')
  end
end
