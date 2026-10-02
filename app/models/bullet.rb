# frozen_string_literal: true

class Bullet < ApplicationRecord
  include Completable, Collectable, Postponable, Archivable, Publishable, Bullet::Pageable,
          Bullet::Searchable, ActivityTrackable

  belongs_to :user
  has_many :bullet_collections, dependent: :destroy
  has_many :collections, through: :bullet_collections

  attr_accessor :collection_id

  has_rich_text :body

  delegated_type :bulletable, types: %w[Text Attachment], dependent: :destroy, optional: true, inverse_of: :bullet
  delegate :icon, :colour, :data_attributes, to: :bulletable

  accepts_nested_attributes_for :bulletable
  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true
  validates :author_name, length: { maximum: 100 }, allow_blank: true

  before_validation :ensure_bulletable, on: :create
  before_validation :default_pops_on
  before_save :capture_filename
  after_create :assign_initial_collection

  scope :active, -> { where.missing(:archive) }
  scope :due, ->(today = Date.current) { where(pops_on: ..today) }
  scope :upcoming, ->(today = Date.current) { where(pops_on: (today + 1.day)..) }
  scope :tagged_with, lambda { |collection|
    joins(:bullet_collections).where(bullet_collections: { collection_id: collection.id }).distinct
  }

  def body_as_text = body.to_plain_text.to_s
  def name         = body_as_text.lines.first&.strip.presence || filename.presence || bulletable.default_name

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

  # Transitional: the file lives on the Attachment record until Task 2 moves it onto Bullet.
  def capture_filename
    self.filename = bulletable.file.filename.to_s if bulletable_type == 'Attachment' && bulletable&.file&.attached?
  end

  def default_pops_on
    self.pops_on ||= Date.current
  end

  def assign_initial_collection
    return if collection_id.blank?

    collect!(collection_id: collection_id)
  end
end
