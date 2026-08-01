# frozen_string_literal: true

class Bullet < ApplicationRecord
  include Migratable, Collectable, Postponable, Archivable, Pinnable, Publishable, Bullet::Pageable,
          Bullet::Projectable, Bullet::Searchable, ActivityTrackable
  belongs_to :user
  belongs_to :bucket
  has_many :activities, as: :subject, dependent: :destroy

  delegated_type :bulletable, types: %w[Task Note Event Voice], dependent: :destroy, optional: true, inverse_of: :bullet
  delegate :completable?, :temporal?, :name, :excerpt, :long?,
           :marker_icon, :completed?,
           :starts_date, :ends_date, :body, :body_as_text, :data_attributes,
           :icon, :colour,
           to: :bulletable

  accepts_nested_attributes_for :bulletable
  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true
  validates :author_name, length: { maximum: 100 }, allow_blank: true

  scope :active, -> { where.missing(:archive) }
  scope :in_review, lambda { |range|
    active
      .joins(:bucket)
      .where(buckets: { bucketable_type: 'Daylog' }, pops_on: range, migrated_at: nil)
  }

  def to_partial_path
    return 'bullets/bullet' unless bulletable

    bulletable.to_partial_path
  end

  def migration_activity
    return unless migrated?

    activities.where(action: last_migration['action']).order(created_at: :desc).first
  end
end
