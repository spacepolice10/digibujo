# frozen_string_literal: true

class Bucket < ApplicationRecord
  include Archivable, Colourable, Iconable, Pinnable, Searchable, ActivityTrackable

  ARCHIVABLE_BUCKETABLE_TYPES = %w[Collection].freeze

  belongs_to :user
  delegated_type :bucketable, types: %w[Collection FutureBucket MonthlyBucket], dependent: :destroy
  has_many :bullets, dependent: :nullify
  has_many :search_selections, as: :searchable, dependent: :destroy, class_name: "Search::Selection"

  has_rich_text :side_note

  scope :expired_archived, lambda {
    archived
      .where(bucketable_type: "Collection")
      .where.not(id: PinnedEntity.where(pinnable_type: "Bucket").select(:pinnable_id))
      .where("archives_on <= ?", Archivable::ARCHIVE_RETENTION_DAYS.days.ago.to_date)
  }

  validates :name, presence: true

  normalizes :name, with: ->(name) { name.strip.downcase }

  after_update :record_updated_activity, if: :trackable_identity_changed?

  def archivable?
    ARCHIVABLE_BUCKETABLE_TYPES.include?(bucketable_type)
  end

  def archive!
    unless archivable?
      errors.add(:base, "cannot archive this bucket type")
      raise ActiveRecord::RecordInvalid, self
    end

    super
    record_activity!("archived", metadata: { "bucketable_type" => bucketable_type })
  end

  def unarchive!
    unless archivable?
      errors.add(:base, "cannot unarchive this bucket type")
      raise ActiveRecord::RecordInvalid, self
    end

    super
    record_activity!("unarchived", metadata: { "bucketable_type" => bucketable_type })
  end

  def searchable?
    !archived?
  end

  def search_name
    name
  end

  def search_body
    [name, side_note&.to_plain_text].compact.join(" ")
  end

  def show_path
    case bucketable
    when Collection
      Rails.application.routes.url_helpers.collection_path(bucketable)
    when MonthlyBucket
      Rails.application.routes.url_helpers.monthly_bucket_path(bucketable)
    when FutureBucket
      Rails.application.routes.url_helpers.future_path
    end
  end

  private

  def trackable_identity_changed?
    saved_change_to_name? || saved_change_to_colour? || saved_change_to_icon?
  end

  def record_updated_activity
    changes = {}
    %w[name colour icon].each do |attribute|
      next unless saved_change_to_attribute?(attribute)

      changes[attribute] = saved_change_to_attribute(attribute)
    end

    record_activity!("updated", metadata: { "changes" => changes })
  end
end
