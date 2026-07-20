# frozen_string_literal: true

class Future < ApplicationRecord
  include Bucketable

  belongs_to :user

  validates :period_from, presence: true, uniqueness: { scope: :user_id }

  before_validation :normalize_period

  scope :covering, lambda { |date = Date.current|
    day = date.to_date
    where(period_from: ..day, period_to: day..)
  }

  def spread_months
    return [] if period_from.blank?

    (0..5).map { |i| period_from + i.months }
  end

  private

  def normalize_period
    return if period_from.blank?

    self.period_from = period_from.to_date.beginning_of_month
    self.period_to = (period_from + 5.months).end_of_month
  end
end
