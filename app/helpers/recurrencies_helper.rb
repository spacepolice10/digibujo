# frozen_string_literal: true

module RecurrenciesHelper
  def recurrency_hint(recurrency, tracker: nil, date: nil)
    parts = [recurrency_schedule_label(recurrency)]

    if tracker && date
      statistics = tracker.statistics(recurrency, as_of: date)
      parts << "#{statistics[:streak]} day streak" if statistics[:streak] > 0
      parts << "Done today" if tracker.completed?(recurrency, date)
    end

    "#{recurrency.name} — #{parts.join(" · ")}"
  end

  def recurrency_schedule_label(recurrency)
    days = recurrency.schedule_days.sort
    return "Every day" if days.size == 7

    days.map { |wday| Date::ABBR_DAYNAMES[wday] }.join(", ")
  end
end
