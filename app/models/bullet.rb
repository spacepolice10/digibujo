# frozen_string_literal: true

class Bullet < ApplicationRecord
  include Migratable, Collectable, Poppable, Bullet::Archivable, Pinnable, Publishable, Bullet::Mentionable,
          Bullet::Searchable, ActivityTrackable

  belongs_to :user
  belongs_to :bucket, optional: true

  delegated_type :bulletable, types: %w[Task Note Event Voice], dependent: :destroy, optional: true

  delegate :completable?, :temporal?, :name,
           :marker_icon, :marker_styles, :completed?, :mood_marker,
           :starts_date, :ends_date,
           to: :bulletable

  accepts_nested_attributes_for :bulletable

  has_rich_text :body

  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true
  validate :voice_caption_present, if: -> { bulletable_type == "Voice" }

  def to_partial_path = bulletable.to_partial_path

  def self.composer_partial_of(type_name)
    "#{type_name.to_s.underscore.pluralize}/composer"
  end

  private

  def voice_caption_present
    return if body.present? && body.to_plain_text.strip.present?

    errors.add(:body, :blank)
  end
end
