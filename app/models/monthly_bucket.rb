# frozen_string_literal: true

class MonthlyBucket < ApplicationRecord
  include Bucketable
  belongs_to :user
  belongs_to :future_bucket

  validates :future_bucket, presence: true
  validates :period_from, presence: true, uniqueness: { scope: :user_id }
  validate :period_ranges_correct
  validate :period_is_full_calendar_month

  def self.current(user, date = Date.current)
    user.monthly_buckets.find_by(period_from: date.beginning_of_month)
  end

  def self.default_period
    {
      period_from: Date.current.beginning_of_month,
      period_to: Date.current.end_of_month
    }
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

  def month
    period_from&.iso8601
  end

  def month=(value)
    @month = value.presence
  end

  before_validation :apply_month_selection, :snap_period_from

  private

  def apply_month_selection
    return if @month.blank?

    date = @month.is_a?(Date) ? @month : Date.parse(@month.to_s)
    self.period_from = date.beginning_of_month
    self.period_to = date.end_of_month
  rescue Date::Error
    errors.add(:month, "is invalid")
  end

  def snap_period_from
    self.period_from = period_from.beginning_of_month if period_from.present?
  end

  def period_ranges_correct
    return if period_from.blank? && period_to.blank?

    if period_from.present? ^ period_to.present?
      errors.add(:base, 'From and To must both be set or both be blank')
      return
    end

    return unless period_from.present? && period_to.present? && period_to < period_from

    errors.add(:period_to, 'must be on or after From')
  end

  def period_is_full_calendar_month
    return unless period_from.present? && period_to.present?
    return if period_to == period_from.end_of_month

    errors.add(:base, 'Spread must cover a full calendar month')
  end
end
