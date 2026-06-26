# frozen_string_literal: true

class Event < ApplicationRecord
  include Bulletable

  composer name: 'Event',
           hint: 'Scheduled occurrence',
           icon: :circle,
           modifier: 'event',
           marker_styles: 'bullet--event-marker',
           hotkey: 'Shift+E'

  def self.permitted_bullet_attributes = %i[starts_date ends_date]

  def temporal?    = true
  def completable? = false
  def marker_icon  = :circle
  def marker_styles = 'bullet--event-marker'
end
