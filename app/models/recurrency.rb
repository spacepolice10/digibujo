# frozen_string_literal: true

class Recurrency < ApplicationRecord
  include Colourable, Iconable

  SCHEDULE_KINDS = %w[daily weekdays custom].freeze

  belongs_to :user
  has_many :completions, class_name: "RecurrencyCompletion", dependent: :restrict_with_error

  scope :chronological, -> { order(created_at: :asc) }

  validates :name, presence: true
  validates :schedule, presence: true
  validate :schedule_shape
  validate :active_range

  def active_on?(date)
    day = date.to_date
    (active_from.nil? || day >= active_from) && (active_to.nil? || day <= active_to)
  end

  def scheduled_on?(date)
    return false unless active_on?(date)

    case schedule_kind
    when "daily"
      true
    when "weekdays"
      date.to_date.on_weekday?
    when "custom"
      Array(schedule["days"]).map(&:to_i).include?(date.to_date.wday)
    else
      false
    end
  end

  def retired?
    active_to.present? && active_to < Date.current
  end

  def schedule_kind
    schedule.fetch("kind", "daily")
  end

  def schedule_label
    case schedule_kind
    when "daily"
      "Daily"
    when "weekdays"
      "Weekdays"
    when "custom"
      day_labels = Array(schedule["days"]).map(&:to_i).sort.map { |wday| Date::ABBR_DAYNAMES[wday] }
      day_labels.join(" ")
    else
      schedule_kind.humanize
    end
  end

  private

  def schedule_shape
    return if schedule.blank?

    kind = schedule["kind"]
    unless SCHEDULE_KINDS.include?(kind)
      errors.add(:schedule, "kind must be daily, weekdays, or custom")
      return
    end

    return unless kind == "custom"

    days = Array(schedule["days"])
    if days.empty?
      errors.add(:schedule, "custom schedule requires at least one day")
      return
    end

    days.each do |day|
      next if day.is_a?(Integer) || day.to_s.match?(/\A[0-6]\z/)

      errors.add(:schedule, "days must be integers 0-6")
      break
    end
  end

  def active_range
    return if active_from.blank? || active_to.blank?
    return if active_to >= active_from

    errors.add(:active_to, "must be on or after active from")
  end
end
