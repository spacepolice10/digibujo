# frozen_string_literal: true

class Event < ApplicationRecord
  include Bulletable

  def temporal? = true
  def starts_date  = self[:starts_date]
  def ends_date    = self[:ends_date]
  def marker_icon  = :circle
  def icon         = :circle
  def colour       = 'magenta'

  def self.permitted_bullet_attributes = %i[id starts_date ends_date]
end
