class Event < ApplicationRecord
  include Cardable

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
    card.content.to_plain_text.lines.first&.strip&.truncate(200).presence || 'Untitled'
  end

end
