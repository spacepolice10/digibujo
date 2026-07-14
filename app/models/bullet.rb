# frozen_string_literal: true

class Bullet < ApplicationRecord
  include Migratable, Collectable, Poppable, Bullet::Archivable, Pinnable, Publishable, Bullet::Mentionable,
          Bullet::Searchable, Bullet::ActivityRecording, ActivityTrackable

  belongs_to :user
  belongs_to :bucket, optional: true

  delegated_type :bulletable, types: %w[Task Note Event Voice], dependent: :destroy, optional: true, inverse_of: :bullet

  delegate :completable?, :temporal?, :name,
           :marker_icon, :completed?, :mood_marker,
           :starts_date, :ends_date, :body, :data_attributes,
           :icon,
           to: :bulletable

  accepts_nested_attributes_for :bulletable

  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true

  def migration_activity
    return unless migrated?

    activities.where(action: last_migration['action']).order(created_at: :desc).first
  end
end
