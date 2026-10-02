# frozen_string_literal: true

class Bullet < ApplicationRecord
  include Completable, Collectable, Postponable, Archivable, Publishable, Bullet::Pageable,
          Bullet::Searchable, ActivityTrackable

  MAX_ATTACHMENT_BYTES = 25.megabytes

  belongs_to :user
  has_many :bullet_collections, dependent: :destroy
  has_many :collections, through: :bullet_collections

  attr_accessor :collection_id

  has_rich_text :body
  has_one_attached :file do |attachable|
    attachable.variant :thumb, resize_to_limit: [400, 160]
    attachable.variant :display, resize_to_limit: [1600, 1600]
  end

  before_save :capture_filename

  validate :content_is_exactly_one_of_file_or_text
  validate :file_must_fit
  validates :author_name, length: { maximum: 100 }, allow_blank: true

  before_validation :default_pops_on
  after_create :assign_initial_collection

  scope :active, -> { where.missing(:archive) }
  scope :due, ->(today = Date.current) { where(pops_on: ..today) }
  scope :upcoming, ->(today = Date.current) { where(pops_on: (today + 1.day)..) }
  scope :tagged_with, lambda { |collection|
    joins(:bullet_collections).where(bullet_collections: { collection_id: collection.id }).distinct
  }

  def body_as_text = body.to_plain_text.to_s
  def name = body_as_text.lines.first&.strip.presence || filename.presence || 'Untitled'

  def marker_icon
    done? ? :check : :circle
  end

  private

  def capture_filename
    self.filename = file.filename.to_s if file.attached?
  end

  def content_is_exactly_one_of_file_or_text
    has_file = file.attached?
    has_text = body_as_text.present?
    errors.add(:base, 'Enter text or attach a file, not both') if has_file == has_text
  end

  def file_must_fit
    return unless file.attached? && file.blob.byte_size > MAX_ATTACHMENT_BYTES

    errors.add(:file, "is too large (maximum is #{MAX_ATTACHMENT_BYTES / 1.megabyte} MB)")
  end

  def default_pops_on
    self.pops_on ||= Date.current
  end

  def assign_initial_collection
    return if collection_id.blank?

    collect!(collection_id: collection_id)
  end
end
