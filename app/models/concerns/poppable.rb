# frozen_string_literal: true

module Poppable
  extend ActiveSupport::Concern

  def pop!(pops_on:)
    assign_pops_on!(pops_on)
    BulletActivityRecorder.record_popped!(bullet: self)
  end

  def unpop!
    update!(pops_on: nil)
  end

  def postpone_next_day!(from: nil)
    anchor = from || pops_on || Time.zone.today
    assign_pops_on!(anchor + 1.day)
    BulletActivityRecorder.record_postponed!(bullet: self)
  end

  def postpone_next_week!(from: nil)
    anchor = from || pops_on || Time.zone.today
    assign_pops_on!(anchor + 1.week)
    BulletActivityRecorder.record_postponed!(bullet: self)
  end

  private

  def assign_pops_on!(date)
    update!(
      pops_on: date,
      triaged_at: triaged_at || Time.current
    )
  end
end
