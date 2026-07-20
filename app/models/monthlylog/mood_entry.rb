# frozen_string_literal: true

class Monthlylog::MoodEntry < ApplicationRecord
  self.table_name = 'monthlylog_mood_entries'

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

  belongs_to :monthlylog

  enum :mood, MOODS, validate: true

  validates :date, presence: true, uniqueness: { scope: :monthlylog_id }
  validate :date_within_month

  def marker
    MOOD_MARKERS[mood&.to_sym]
  end

  private

  def date_within_month
    return if date.blank? || monthlylog.blank?
    return if monthlylog.spread_days.include?(date.to_date)

    errors.add(:date, 'must be within the monthly spread')
  end
end
