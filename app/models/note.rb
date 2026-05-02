class Note < ApplicationRecord
  include Bulletable

  def self.icon   = 'line-dashed'
  def self.colour = '5'
  def self.name   = 'Note'
  def self.marker = '-'

  def excerpt
    bullet.content.to_plain_text.strip.presence || ""
  end
end
