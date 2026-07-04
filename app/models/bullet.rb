# frozen_string_literal: true

class Bullet < ApplicationRecord
  include Migratable, Collectable, Poppable, Bullet::Archivable, Pinnable, Publishable, Bullet::Mentionable,
          Bullet::Searchable, Bullet::ActivityRecording, ActivityTrackable

  belongs_to :user
  belongs_to :bucket, optional: true

  delegated_type :bulletable, types: %w[Task Note Event Voice], dependent: :destroy, optional: true, inverse_of: :bullet

  delegate :completable?, :temporal?, :name,
           :marker_icon, :completed?, :mood_marker,
           :starts_date, :ends_date, :body,
           to: :bulletable

  def assign_attributes(new_attributes)
    attrs = new_attributes.stringify_keys
    body_content = attrs.delete('body')
    super(attrs)
    return unless body_content && bulletable

    bulletable.body = body_content
    bulletable.save! if persisted? && bulletable.persisted?
  end

  def body=(value)
    bulletable.body = value if bulletable
  end

  accepts_nested_attributes_for :bulletable

  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true
  validate :bucket_belongs_to_user

  def to_partial_path = bulletable.to_partial_path

  def self.composer_partial_of(type_name)
    "#{type_name.to_s.underscore.pluralize}/composer"
  end

  scope :in_review_period, lambda { |from, to|
    active.where(bucket_id: nil, migrated_at: nil, pops_on: from..to)
  }

  private

  def bucket_belongs_to_user
    return if bucket_id.blank?
    return if bucket&.user_id == user_id

    errors.add(:bucket_id, :invalid)
  end
end
