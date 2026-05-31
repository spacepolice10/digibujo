class Note < ApplicationRecord
  include Bulletable

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
    bullet.content.to_plain_text.strip.presence || "Untitled"
  end
end
