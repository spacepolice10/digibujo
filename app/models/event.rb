# frozen_string_literal: true

class Event < ApplicationRecord
  include Bulletable

  composer label: 'Event',
           hint: 'Scheduled occurrence',
           icon: :circle,
           modifier: 'event',
           marker_styles: 'bullet--event-marker'

  def temporal?      = true
  def completable?   = false
  def marker_icon    = :circle
  def marker_styles  = 'bullet--event-marker'
end
