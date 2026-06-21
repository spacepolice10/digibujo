# frozen_string_literal: true

class RecurrencyTracker
  attr_reader :user, :from, :to

  def initialize(user:, from:, to:)
    @user = user
    @from = from.to_date
    @to = to.to_date
    raise ArgumentError, "from must be on or before to" if @from > @to

    load_data
  end

  def recurrencies
    @recurrencies
  end

  def completed?(recurrency, date)
    @completions_by_recurrency[recurrency.id]&.include?(date.to_date)
  end

  def completions_for(recurrency)
    @completions_by_recurrency[recurrency.id] || Set.new
  end

  def stats(recurrency, as_of: Date.current)
    range_to = [to, as_of].min
    scheduled_days = scheduled_days_for(recurrency, from: recurrency_range_from(recurrency), to: range_to)
    completed_days = scheduled_days.count { |day| completed?(recurrency, day) }
    completion_dates = completion_dates_for(recurrency)

    {
      streak: current_streak(recurrency, as_of: as_of, completion_dates: completion_dates),
      best_streak: best_streak(recurrency, completion_dates: completion_dates),
      total: completion_dates.size,
      period_completed: completed_days,
      period_scheduled: scheduled_days.size
    }
  end

  def scheduled_on?(recurrency, date)
    recurrency.scheduled_on?(date) && date_in_tracker_range?(date)
  end

  private

  def load_data
    @recurrencies = user.recurrencies.chronological.select { |recurrency| overlaps_tracker?(recurrency) }
    recurrency_ids = @recurrencies.map(&:id)
    completions = RecurrencyCompletion.where(recurrency_id: recurrency_ids, date: from..to)
    @completions_by_recurrency = completions.group_by(&:recurrency_id).transform_values do |rows|
      rows.map(&:date).to_set
    end
  end

  def overlaps_tracker?(recurrency)
    range_from = recurrency.active_from || from
    range_to = recurrency.active_to || to
    range_from <= to && range_to >= from
  end

  def recurrency_range_from(recurrency)
    [from, recurrency.active_from].compact.max
  end

  def recurrency_range_to(recurrency)
    [to, recurrency.active_to].compact.min
  end

  def date_in_tracker_range?(date)
    day = date.to_date
    day >= from && day <= to
  end

  def scheduled_days_for(recurrency, from:, to:)
    return [] if from > to

    (from..to).select { |day| recurrency.scheduled_on?(day) }
  end

  def current_streak(recurrency, as_of:, completion_dates:)
    streak = 0
    day = as_of.to_date

    loop do
      break unless recurrency.scheduled_on?(day)

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

  def best_streak(recurrency, completion_dates:)
    return 0 if completion_dates.empty?

    best = 0
    run = 0
    scheduled_days_for(recurrency, from: completion_dates.min, to: completion_dates.max).each do |day|
      if completion_dates.include?(day)
        run += 1
        best = [best, run].max
      else
        run = 0
      end
    end

    best
  end

  def completion_dates_for(recurrency)
    recurrency.completions.pluck(:date).to_set
  end
end
