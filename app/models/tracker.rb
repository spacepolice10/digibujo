# frozen_string_literal: true

class Tracker < ApplicationRecord
  include Colourable, Iconable

  DEFAULT_SCHEDULE = { 'days' => (0..6).to_a }.freeze

  belongs_to :user
  has_many :statuses, class_name: 'Tracker::Status', dependent: :destroy

  scope :chronological, -> { order(created_at: :asc) }

  validates :name, presence: true
  validates :schedule, presence: true
  validates :start_date, presence: true

  def self.with_completions
    records = all.to_a
    ids = records.map(&:id)
    dates_by_tracker = Tracker::Status.where(tracker_id: ids)
                                      .includes(:calendar_date)
                                      .group_by(&:tracker_id)
                                      .transform_values { |rows| rows.map(&:date).to_set }

    records.each { |tracker| tracker.preload_completion_dates!(dates_by_tracker[tracker.id] || Set.new) }
    records
  end

  def active_from
    start_date
  end

  def active_to
    Date.current
  end

  def active_on?(date)
    day = date.to_date
    day >= start_date && day <= Date.current
  end

  def scheduled_on?(date)
    return false unless active_on?(date)

    schedule_days.include?(date.to_date.wday)
  end

  def schedule_days
    Array(schedule['days']).map(&:to_i)
  end

  def preload_completion_dates!(dates)
    @completion_dates = dates.is_a?(Set) ? dates : dates.to_set
  end

  def completed?(date)
    completion_dates.include?(date.to_date)
  end

  def statistics(as_of: Date.current)
    as_of = as_of.to_date
    range_to = [active_to, as_of].min
    range_from = active_from
    scheduled_days = scheduled_days_for(from: range_from, to: range_to)
    dates = completion_dates

    {
      streak: current_streak(as_of: as_of, completion_dates: dates),
      best_streak: best_streak(completion_dates: dates),
      total: dates.size,
      period_completed: scheduled_days.count { |day| dates.include?(day) },
      period_scheduled: scheduled_days.size
    }
  end

  private

  def completion_dates
    @completion_dates ||= statuses.joins(:calendar_date).pluck("calendar_dates.date").to_set
  end

  def scheduled_days_for(from:, to:)
    return [] if from > to

    (from..to).select { |day| scheduled_on?(day) }
  end

  def current_streak(as_of:, completion_dates:)
    streak = 0
    day = as_of.to_date

    loop do
      break unless scheduled_on?(day)

      if completion_dates.include?(day)
        streak += 1
        day -= 1
      elsif day == as_of.to_date
        day -= 1
      else
        break
      end
    end

    streak
  end

  def best_streak(completion_dates:)
    return 0 if completion_dates.empty?

    best = 0
    run = 0
    scheduled_days_for(from: completion_dates.min, to: completion_dates.max).each do |day|
      if completion_dates.include?(day)
        run += 1
        best = [best, run].max
      else
        run = 0
      end
    end

    best
  end
end
