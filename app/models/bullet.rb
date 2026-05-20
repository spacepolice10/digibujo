# frozen_string_literal: true

class Bullet < ApplicationRecord
  include Contextable, Collectable, Schedulable, Archivable, Pinnable, Publishable,
          TracksBulletActivity

  scope :scheduled_on_date, lambda { |date|
    where(scheduled_on: date)
      .or(where(scheduled_on: nil, created_at: date.beginning_of_day..date.end_of_day))
      .distinct
  }
  scope :daily_log, ->(date) { scheduled_on_date(date).where(archived: false) }
  scope :monthly_log, ->(date) { where(scheduled_on: date.beginning_of_month..date.end_of_month).where(archived: false) }

  belongs_to :user
  belongs_to :bucket, optional: true, inverse_of: :bullets
  has_many :bullet_activities, foreign_key: :bullet_id, inverse_of: false
  delegated_type :bulletable, types: %w[Task Note Event], dependent: :destroy, optional: true
  delegate :completable?, :temporal?, :icon, :colour, :name, :marker, to: :bulletable
  accepts_nested_attributes_for :bulletable

  has_rich_text :content

  validates :content, presence: true
  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true

  def to_partial_path = bulletable.to_partial_path

  def self.type_capabilities(type_name)
    return Bulletable::DEFAULT_CAPABILITIES unless bulletable_types.include?(type_name)

    type_name.constantize.capabilities
  end

end
