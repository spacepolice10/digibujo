# frozen_string_literal: true

class Note < ApplicationRecord
  include Bulletable

  enum :mood, { positive: 0, negative: 1, inspired: 2, frustrated: 3 }

  MOOD_MARKERS = {
    positive: '😊',
    negative: '😞',
    inspired: '✨',
    frustrated: '😣'
  }.freeze

  def self.permitted_bullet_attributes = %i[mood]

  def temporal?                = false
  def completable?             = false
  def starts_date              = nil
  def ends_date                = nil
  def marker_styles            = 'bullet--note-marker'
  def body
    text = bullet.body.to_plain_text
    if text.length > 400
      text.truncate(400) || 'Untitled'
    else
      bullet.body
    end
  end

  def mood_marker
    MOOD_MARKERS[mood&.to_sym]
  end
end
