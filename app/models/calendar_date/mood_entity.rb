# frozen_string_literal: true

class CalendarDate::MoodEntity < ApplicationRecord
  self.table_name = 'calendar_date_mood_entities'

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

  belongs_to :calendar_date

  enum :mood, MOODS, validate: true

  delegate :date, to: :calendar_date

  validates :calendar_date_id, uniqueness: true

  def marker
    MOOD_MARKERS[mood&.to_sym]
  end
end
