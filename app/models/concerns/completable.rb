# frozen_string_literal: true

module Completable
  extend ActiveSupport::Concern

  def complete!
    update!(done: true, done_at: Time.current)
    BulletActivityRecorder.record_completed!(bullet: bullet)
  end

  def uncomplete!
    update!(done: false, done_at: nil)
    BulletActivityRecorder.record_uncompleted!(bullet: bullet)
  end
end
