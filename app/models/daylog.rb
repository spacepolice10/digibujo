class Daylog < ApplicationRecord
  include Cardable

  enum :mood, { excellent: 0, fine: 1, medium: 2, terrible: 3 }

  MOOD_EMOJIS = { "excellent" => "😄", "fine" => "🙂", "medium" => "😑", "terrible" => "😢" }.freeze

  def mood_emoji = MOOD_EMOJIS[mood]
  def form_fields = [:mood_picker]
end
