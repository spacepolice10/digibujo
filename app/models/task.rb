class Task < ApplicationRecord
  include Cardable

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

  def name
    card.content.to_plain_text.lines.first&.strip&.truncate(200).presence || 'Untitled'
  end

end
