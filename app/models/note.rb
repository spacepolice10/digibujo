class Note < ApplicationRecord
  include Bulletable

  enum :mood, { positive: 0, negative: 1, inspired: 2, pain: 3 }

  def temporal?
    false
  end

  def completable?
    false
  end

  def name
    bullet.content.to_plain_text.strip.presence || "Untitled"
  end

  def excerpt
    text = bullet.content.to_plain_text
    if text.length > 400
     text.truncate(400) || "Untitled"
    else 
      bullet.content
    end
  end
end
