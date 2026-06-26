# frozen_string_literal: true

class Recurrency < ApplicationRecord
  include Colourable, Iconable

  DEFAULT_SCHEDULE = { 'days' => (0..6).to_a }.freeze

  belongs_to :user
  has_many :completions, class_name: 'RecurrencyCompletion', dependent: :restrict_with_error

  scope :chronological, -> { order(created_at: :asc) }

  validates :name, presence: true
  validates :schedule, presence: true

  def active_from
    created_at.to_date
  end

  def active_on?(date)
    date.to_date >= active_from
  end

  def scheduled_on?(date)
    return false unless active_on?(date)

    schedule_days.include?(date.to_date.wday)
  end

  def schedule_days
    Array(schedule['days']).map(&:to_i)
  end
end
