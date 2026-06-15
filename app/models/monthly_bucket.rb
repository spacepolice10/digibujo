# frozen_string_literal: true

class MonthlyBucket < ApplicationRecord
  include Bucketable, Periodable
  belongs_to :user
  belongs_to :future_bucket, optional: true

  def self.current(user)
    user.monthly_buckets.order(created_at: :desc).first
  end

  before_validation :snap_period_from

  private

  def snap_period_from
    self.period_from = period_from.beginning_of_month if period_from.present?
  end
end
