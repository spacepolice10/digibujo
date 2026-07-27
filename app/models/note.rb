# frozen_string_literal: true

class Note < ApplicationRecord
  include Bulletable

  def marker_icon              = :text
  def icon                     = :text
  def colour                   = 'gold'

  def self.permitted_bullet_attributes = %i[id body]
end
