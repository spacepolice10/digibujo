# frozen_string_literal: true

class Bullet < ApplicationRecord
  EXCERPT_LIMIT = 400

  include Completable, Collectable, Postponable, Archivable, Publishable, Bullet::Pageable,
          Bullet::Projectable, Bullet::Searchable, ActivityTrackable

  belongs_to :user
  belongs_to :collection, optional: true

  has_rich_text :body

  delegated_type :bulletable, types: %w[Text Memo], dependent: :destroy, optional: true, inverse_of: :bullet
  delegate :icon, :colour, :data_attributes, to: :bulletable

  accepts_nested_attributes_for :bulletable
  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true
  validates :author_name, length: { maximum: 100 }, allow_blank: true

  before_validation :ensure_bulletable, on: :create
  before_validation :default_pops_on

  scope :active, -> { where.missing(:archive) }
  scope :on_timeline, -> { where(collection_id: nil) }
  scope :due, ->(today = Date.current) { where(pops_on: ..today) }
  scope :upcoming, ->(today = Date.current) { where(pops_on: (today + 1.day)..) }

  def body_as_text = body.to_plain_text.to_s
  def name         = body_as_text.lines.first&.strip.presence || 'Untitled'
  def long?        = body_as_text.length > EXCERPT_LIMIT
  def excerpt      = bulletable.excerpt_for(body)

  def marker_icon
    done? ? :check : bulletable.marker_icon
  end

  def to_partial_path
    bulletable.to_partial_path
  end

  private

  def ensure_bulletable
    build_bulletable if bulletable.blank?
  end

  def default_pops_on
    self.pops_on ||= Date.current
  end
end
