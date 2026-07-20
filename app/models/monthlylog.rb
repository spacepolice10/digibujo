# frozen_string_literal: true

class Monthlylog < ApplicationRecord
  include Bucketable

  belongs_to :user
  has_many :trackers, dependent: :destroy
  has_many :mood_entries, class_name: 'Monthlylog::MoodEntry', dependent: :destroy

  validates :period_from, presence: true, uniqueness: { scope: :user_id }

  before_validation :normalize_period

  scope :covering, lambda { |date = Date.current|
    day = date.to_date
    where(period_from: ..day, period_to: day..)
  }

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
