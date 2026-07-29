# frozen_string_literal: true

class Daylog::Picture < ApplicationRecord
  self.table_name = 'daylog_pictures'

  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze

  belongs_to :daylog

  has_one_attached :picture do |attachable|
    ImageVariant::TRANSFORMATIONS.each do |name, transformations|
      attachable.variant name, **transformations
    end
  end

  validates :date, uniqueness: { scope: :daylog_id }
  validate :picture_must_be_present
  validate :picture_must_be_allowed_type

  private

  def picture_must_be_present
    errors.add(:picture, :blank) unless picture.attached?
  end

  def picture_must_be_allowed_type
    return unless picture.attached?

    content_type = picture.blob.content_type.to_s.split(';').first
    return if content_type.in?(ALLOWED_CONTENT_TYPES)

    errors.add(:picture, 'has an invalid content type')
  end
end
