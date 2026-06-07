# frozen_string_literal: true

class Bullet < ApplicationRecord
  include Collectable, Poppable, Archivable, Pinnable, Publishable

  scope :chronological, -> { order(created_at: :asc) }
  scope :pops_on_date, lambda { |date|
    where(pops_on: date).distinct
  }
  scope :dailylog, ->(date) { pops_on_date(date).where(archived: false) }
  scope :monthlylog, ->(date) { where(pops_on: date.beginning_of_month..date.end_of_month).where(archived: false) }

  belongs_to :user
  belongs_to :bucket, optional: true, inverse_of: :bullets

  delegated_type :bulletable, types: %w[Task Note Event Group], dependent: :destroy, optional: true
  delegate :completable?, :temporal?, :name, :excerpt, to: :bulletable

  accepts_nested_attributes_for :bulletable

  has_many :bullet_activities, foreign_key: :bullet_id, inverse_of: false
  has_rich_text :content

  validates :content, presence: true
  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true

  def to_partial_path = bulletable.to_partial_path
end
