# frozen_string_literal: true

module Completable
  extend ActiveSupport::Concern

  def complete!
    update!(done: true, done_at: Time.current)
    bullet.stamp_migration!(kind: "completed", pops_on: bullet.pops_on)
  end

  def uncomplete!
    update!(done: false, done_at: nil)
    bullet.record_activity!("uncompleted")
  end
end
