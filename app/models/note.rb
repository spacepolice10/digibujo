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

  def self.permitted_bullet_attributes = %i[body mood]

  def temporal?                = false
  def completable?             = false
  def starts_date              = nil
  def ends_date                = nil
  def marker_styles            = 'bullet--note-marker'
  def marker_icon              = :line_dashed

  def excerpt
    text = body.to_plain_text
    if text.length > 800
      text.truncate(800) || 'Untitled'
    else
      body
    end
  end

  def mood_marker
    MOOD_MARKERS[mood&.to_sym]
  end
end
