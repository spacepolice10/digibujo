class Note < ApplicationRecord
  include Cardable

  RICH_TEXT_PREVIEW_MAX_CHARS = 280

  def self.icon   = 'line-dashed'
  def self.colour = '5'
  def self.name   = 'Note'
  def self.marker = '-'

  def excerpt
    card.content.to_plain_text.strip&.truncate(RICH_TEXT_PREVIEW_MAX_CHARS).presence || ''
  end
end
