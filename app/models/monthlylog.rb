# frozen_string_literal: true

class Monthlylog < ApplicationRecord
  self.table_name = "monthlylogs"

  include Bucketable

  scope :covering, lambda { |date = Date.current|
    joins(:bucket).merge(Bucket.monthlylog_buckets.where(period_from: date.beginning_of_month))
  }

  def self.current(user)
    user.monthlylogs.covering.first
  end

  def current?
    period_from == Date.current.beginning_of_month
  end
end
