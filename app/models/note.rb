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
  def marker_icon              = :line_dashed

  def long?
    body.to_plain_text.length > 400
  end

  def name
    body.to_plain_text.lines.first&.strip
  end

  def excerpt
    text = body.to_plain_text
    excerpt_text = text.lines[1..]&.join('') || ''
    long? ? excerpt_text.truncate(400) : body
  end

  def mood_marker
    MOOD_MARKERS[mood&.to_sym]
  end
end
