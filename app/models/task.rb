class Task < ApplicationRecord
  include Bulletable

  def temporal?
    true
  end

  def completable?
    true
  end

  def name
    bullet.content.to_plain_text.strip.presence || "Untitled"
  end

  def excerpt
    bullet.content.to_plain_text.strip.presence || "Untitled"
  end

  def complete!
    update!(done: true, done_at: Time.current)
    BulletActivityRecorder.record_completed!(bullet: bullet)
  end

  def uncomplete!
    update!(done: false, done_at: nil)
    BulletActivityRecorder.record_uncompleted!(bullet: bullet)
  end


end
