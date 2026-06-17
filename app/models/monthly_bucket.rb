# frozen_string_literal: true

class MonthlyBucket < ApplicationRecord
  include Bucketable, Periodable
  belongs_to :user
  belongs_to :future_bucket

  validates :future_bucket, presence: true

  def self.current(user)
    user.monthly_buckets.order(created_at: :desc).first
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
end
