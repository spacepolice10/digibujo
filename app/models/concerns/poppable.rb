# frozen_string_literal: true

module Poppable
  extend ActiveSupport::Concern

  def pop!(pops_on:)
    update!(
      pops_on: pops_on,
      triaged_at: triaged_at || Time.current
    )
    BulletActivityRecorder.record_popped!(bullet: self)
  end

  def unpop!(previous_pops_on:)
    update!(pops_on: previous_pops_on)
  end
end
