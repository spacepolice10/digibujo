class Event < ApplicationRecord
  include Bulletable

  def self.icon   = 'circle'
  def self.colour = '6'
  def self.name   = 'Event'
  def self.marker = '○'

  def temporal?
    true
  end

  def completable?
    false
  end

  def name
    bullet.content.to_plain_text.strip.presence || "Untitled"
  end
end
