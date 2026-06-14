# frozen_string_literal: true

class Bullet < ApplicationRecord
  include Collectable, Poppable, Archivable, Pinnable, Publishable, Projectable, Personable

  scope :chronological, -> { order(created_at: :asc) }
  scope :pops_on_date, lambda { |date|
    where(pops_on: date).distinct
  }
  scope :dailylog, ->(date) { pops_on_date(date).where(archived: false) }

  belongs_to :user
  belongs_to :bucket, optional: true

  delegated_type :bulletable, types: %w[Task Note Event], dependent: :destroy, optional: true
  delegate :completable?, :temporal?, :name, :excerpt, :body,
           :marker_icon, :marker_styles, :completed?, :meta_labels,
           :mood_marker, to: :bulletable

  accepts_nested_attributes_for :bulletable

  has_many :bullet_activities, foreign_key: :bullet_id, inverse_of: false
  has_rich_text :content

  validate :content_or_projects_present
  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true

  private

  def content_or_projects_present
    return if projects.any? || people.any?
    return if rich_text_body_present?

    errors.add(:content, :blank)
  end

  def rich_text_body_present?
    body = content&.body
    return false unless body

    body.to_plain_text.present? || body.attachables.grep(Project).any? || body.attachables.grep(Person).any?
  end
end
