# frozen_string_literal: true

class Event < ApplicationRecord
  include Bulletable

  def self.permitted_bullet_attributes = %i[body starts_date ends_date]

  def temporal?    = true
  def completable? = false
  def marker_icon  = :circle
  def marker_styles = 'bullet--event-marker'
end
