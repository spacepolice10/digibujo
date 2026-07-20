# frozen_string_literal: true

class Monthlylog < ApplicationRecord
  include Bucketable

  belongs_to :user

  validates :period_from, presence: true, uniqueness: { scope: :user_id }

  before_validation :normalize_period

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

  def normalize_period
    return if period_from.blank?

    self.period_from = period_from.to_date.beginning_of_month
    self.period_to = period_from.end_of_month
  end
end
