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

  scope :in_review, lambda { |range|
    active
      .joins(:bucket)
      .where(buckets: { bucketable_type: 'Daylog' }, pops_on: range, migrated_at: nil)
  }

  def to_partial_path
    return 'bullets/bullet' unless bulletable

    bulletable.to_partial_path
  end

  def to_form_path
    bulletable.to_form_path
  end

  def pending?
    bucket&.bucketable_type == 'Pending'
  end

  def monthly_planned_for?(date = Date.current)
    bucket&.bucketable_type == 'Monthlylog' && pops_on == date
  end

  def in_pending_inbox?(date: Date.current)
    pending? || monthly_planned_for?(date)
  end

  def accept_from_pending!
    raise ArgumentError, 'bullet is not in the pending inbox' unless in_pending_inbox?

    daylog_bucket = user.daylog&.bucket
    raise ArgumentError, 'daylog is required' if daylog_bucket.blank?

    postpone!(bucket: daylog_bucket, pops_on: Date.current)
  end

  def migration_activity
    return unless migrated?

    activities.where(action: last_migration['action']).order(created_at: :desc).first
  end
end