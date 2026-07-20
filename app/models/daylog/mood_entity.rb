# frozen_string_literal: true

class Daylog::MoodEntity < ApplicationRecord
  self.table_name = 'daylog_mood_entities'

  MOODS = {
    positive: 0,
    negative: 1,
    inspired: 2,
    frustrated: 3
  }.freeze

  MOOD_MARKERS = {
    positive: '😊',
    negative: '😞',
    inspired: '✨',
    frustrated: '😣'
  }.freeze

  belongs_to :daylog

  enum :mood, MOODS, validate: true

  validates :date, uniqueness: { scope: :daylog_id }

  def marker
    MOOD_MARKERS[mood&.to_sym]
  end
end
