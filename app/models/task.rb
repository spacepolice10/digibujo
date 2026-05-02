class Task < ApplicationRecord
  include Bulletable

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
    bullet.content.to_plain_text.strip.presence || 'Untitled'
  end

end
