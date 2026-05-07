class Task < ApplicationRecord
  include Bulletable
  ARCHIVE_IN_DAYS = 7

  def self.icon   = 'square'
  def self.colour = '2'
  def self.name   = 'Task'
  def self.marker = '•'

  def temporal?
    true
  end

  def completable?
    true
  end

  def done?
    done
  end

  def complete!
    update!(
      done: true,
      done_at: Time.current,
      archived_at: ARCHIVE_IN_DAYS.days.from_now
    )
  end

  def uncomplete!
    update!(done: false, done_at: nil, archived_at: nil)
  end

  def name
    bullet.content
  end
end
