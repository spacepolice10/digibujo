# frozen_string_literal: true

class Event < ApplicationRecord
  include Bulletable

  def temporal? = true
  def completable? = false
  def marker_icon  = :circle
  def icon         = :circle
  def colour       = 'magenta'
  def placeholder  = 'Write down appointments or notable events…'

  def self.permitted_bullet_attributes = %i[body starts_date ends_date]
end
