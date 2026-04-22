class Task < ApplicationRecord
  include Cardable

  def self.icon   = 'square'
  def self.colour = '2'
  def self.name   = 'Task'
  def self.marker = '•'

  def temporal?
    true
  end

  def completable?
    true
  end

  def form_fields = %i[date_picker tags_picker]
end
