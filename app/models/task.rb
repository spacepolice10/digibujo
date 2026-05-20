class Task < ApplicationRecord
  include TracksBulletActivity, Bulletable

  def self.icon   = 'square'
  def self.colour = '2'
  def self.name   = 'Task'
  def self.marker = '-'

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
    update!(done: true, done_at: Time.current)
  end

  def uncomplete!
    update!(done: false, done_at: nil)
  end

  def name
    bullet.content
  end
end
