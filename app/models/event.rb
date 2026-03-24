class Event < ApplicationRecord
  include Cardable

  def self.icon   = 'calendar'
  def self.colour = '6'
  def self.name   = 'Event'
  def self.marker = '○'

  def temporal?
    true
  end

  def completable?
    false
  end

  def form_fields = %i[date_picker ends_date_picker tags_picker]
end
