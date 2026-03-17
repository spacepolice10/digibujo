module Completable
  extend ActiveSupport::Concern

  ARCHIVE_AFTER_DAYS = 7

  def done?
    completable? && done
  end

  def complete!
    update!(done: true, done_at: Time.current, archives_on: ARCHIVE_AFTER_DAYS.days.from_now.to_date)
  end

  def uncomplete!
    update!(done: false, done_at: nil, archives_on: nil)
  end
end
