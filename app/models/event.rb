class Event < ApplicationRecord
  include Bulletable

  def temporal?      = true
  def completable?   = false
  def marker_icon    = :circle
  def marker_styles  = "bullet--event-marker"
end
