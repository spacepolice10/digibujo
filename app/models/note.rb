# frozen_string_literal: true

class Note < ApplicationRecord
  include Bulletable

  def marker_icon              = :text
  def icon                     = :text
  def colour                   = 'gold'

  def self.permitted_bullet_attributes = %i[id body]

  def excerpt
    return 'Untitled' if body_as_text.strip.empty?
    return body unless long?

    body_as_text.lines.drop(1).join.truncate(EXCERPT_LIMIT)
  end
end
