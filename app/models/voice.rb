# frozen_string_literal: true

# Audio-backed bulletable type for short voice memos.
class Voice < ApplicationRecord
  include Bulletable

  DURATION_SECONDS = 60

  has_one_attached :recording

  validates :duration_seconds, numericality: { only_integer: true, in: 1..DURATION_SECONDS }
  validate :recording_must_be_present
  validate :recording_must_be_allowed_type
  validate :caption_present

  def self.permitted_bullet_attributes = %i[body recording duration_seconds]

  def marker_icon   = :microphone
  def placeholder   = 'Caption this voice memo…'
  def focusing_on_render? = false
  def stimulus_controller = "voice-recorder"
  def stimulus_actions = 'turbo:submit-end->voice-recorder#clearOnSubmit'
  def to_toolbar_path = "voices/toolbar"

  private

  def caption_present
    return if body.present? && body.to_plain_text.strip.present?

    errors.add(:body, :blank)
  end

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
