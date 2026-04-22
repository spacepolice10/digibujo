class Note < ApplicationRecord
  include Cardable

  def self.icon   = 'line-dashed'
  def self.colour = '5'
  def self.name   = 'Note'
  def self.marker = '-'

  def form_fields = [:tags_picker]
end
