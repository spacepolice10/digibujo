# frozen_string_literal: true

# Audio-backed bulletable type for short voice memos.
class Voice < ApplicationRecord
  include Bulletable

  MAX_DURATION_SECONDS = 60

  has_one_attached :recording

  validates :duration_seconds, numericality: { only_integer: true, in: 1..MAX_DURATION_SECONDS }
  validate :recording_must_be_present
  validate :recording_must_be_allowed_type

  def self.permitted_bullet_attributes = %i[recording duration_seconds]

  def temporal?     = false
  def completable?  = false
  def starts_date   = nil
  def ends_date     = nil
  def marker_icon   = :microphone
  def marker_styles = 'bullet--voice-marker'
  def name          = bullet.body.to_plain_text.strip.presence || 'Voice memo'

  private

  def recording_must_be_present
    errors.add(:recording, :blank) unless recording.attached?
  end

  def recording_must_be_allowed_type
    return unless recording.attached?

    content_type = recording.blob.content_type.to_s.split(';').first
    return if content_type.in?(%w[audio/webm audio/mp4])

    errors.add(:recording, 'has an invalid content type')
  end
end
