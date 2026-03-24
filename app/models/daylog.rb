class Daylog < ApplicationRecord
  include Cardable

  def self.icon   = 'book'
  def self.colour = '4'
  def self.name   = 'Daylog'

  enum :mood, { excellent: 0, fine: 1, medium: 2, terrible: 3 }

  MOOD_EMOJIS = { "excellent" => "😄", "fine" => "🙂", "medium" => "😑", "terrible" => "😢" }.freeze

  def mood_emoji = MOOD_EMOJIS[mood]
  def form_fields = [:mood_picker]
end
