# frozen_string_literal: true

class Note < ApplicationRecord
  include Bulletable

  def marker_icon              = :text
  def icon                     = :text
  def colour                   = 'gold'

  def self.permitted_bullet_attributes = %i[id]

  def excerpt_for(body)
    text = body.to_plain_text.to_s
    return 'Untitled' if text.strip.empty?
    return body unless text.length > Bullet::EXCERPT_LIMIT

    text.lines.drop(1).join.truncate(Bullet::EXCERPT_LIMIT)
  end
end
