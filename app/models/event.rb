class Event < ApplicationRecord
  include Bulletable

  def temporal?
    true
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
