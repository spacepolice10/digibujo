# frozen_string_literal: true

class Bullet < ApplicationRecord
  include Collectable, Poppable, Archivable, Pinnable, Publishable, Projectable, Personable, RichBodySanitizable

  scope :chronological, -> { order(created_at: :asc) }
  scope :pops_on_date, lambda { |date|
    where(pops_on: date).distinct
  }
  scope :dailylog, ->(date) { pops_on_date(date).where(archived: false) }

  belongs_to :user
  belongs_to :bucket, optional: true

  delegated_type :bulletable, types: %w[Task Note Event Title], dependent: :destroy, optional: true
  delegate :completable?, :temporal?, :name, :excerpt,
           :marker_icon, :marker_styles, :completed?, :meta_labels,
           :mood_marker, to: :bulletable

  accepts_nested_attributes_for :bulletable

  has_many :bullet_activities, foreign_key: :bullet_id, inverse_of: false
  has_rich_text :body
  has_rich_text :rich_body
  has_many_attached :attachments

  validate :body_or_rich_body_present
  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true

  def rich_body?
    rich_body.present? && rich_body.to_plain_text.present?
  end

  private

  def body_or_rich_body_present
    return if body.present? || rich_body.present?
    return if attachments.attached?

    errors.add(:body, "can't be blank")
  end
end
