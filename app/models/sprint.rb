# frozen_string_literal: true

class Sprint < ApplicationRecord
  include Bucketable

  class_attribute :enabled, default: false

  def self.enabled?
    enabled
  end

  validates :starts_on, presence: true
  validates :ends_on, presence: true
  validate :ends_on_on_or_after_starts_on

  def status(on: Date.current)
    date = on.to_date
    return :upcoming if date < starts_on
    return :ended if date > ends_on

    :active
  end

  def days_remaining(on: Date.current)
    case status(on: on)
    when :ended then 0
    when :upcoming then (starts_on - on).to_i
    else (ends_on - on).to_i
    end
  end

  def task_progress
    tasks = bucket.bullets.active.where(bulletable_type: "Task").includes(:bulletable)
    total = tasks.size
    return { total: 0, completed: 0, percent: nil } if total.zero?

    completed = tasks.count(&:completed?)
    {
      total: total,
      completed: completed,
      percent: (completed * 100.0 / total).round
    }
  end

  private

  def ends_on_on_or_after_starts_on
    return if starts_on.blank? || ends_on.blank?
    return if ends_on >= starts_on

    errors.add(:ends_on, "must be on or after the start date")
  end
end
