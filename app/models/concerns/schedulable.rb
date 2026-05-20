module Schedulable
  extend ActiveSupport::Concern

  def schedule!(scheduled_on: nil)
    attrs = { triaged_at: triaged_at || Time.current }
    attrs[:scheduled_on] = scheduled_on if scheduled_on.present?
    update!(attrs)
  end

  # Moves +scheduled_on+ forward by one day. When +from+ is set (e.g. a review day),
  # the next day is computed from that anchor; otherwise uses +scheduled_on+ if present,
  # or +Time.zone.today+.
  def postpone!(from: nil)
    anchor = from || scheduled_on || Time.zone.today
    update!(
      scheduled_on: anchor + 1.day,
      triaged_at: triaged_at || Time.current
    )
  end
end
