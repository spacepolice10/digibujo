# frozen_string_literal: true

class Note < ApplicationRecord
  include Bulletable

  has_rich_text :body

  def marker_icon              = :text
  def icon                     = :text
  def colour                   = 'gold'

  def long?
    body.to_plain_text.length > 400
  end

  def name
    body.to_plain_text.lines.first&.strip
  end

  def excerpt
    text = body.to_plain_text
    excerpt_text = text.lines[1..]&.join('') || ''
    long? ? excerpt_text.truncate(400) : body
  end

  def self.permitted_bullet_attributes = %i[id body]
end
