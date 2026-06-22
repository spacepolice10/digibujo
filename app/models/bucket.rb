# frozen_string_literal: true

class Bucket < ApplicationRecord
  include Archivable, Colourable, Iconable, Pinnable, Searchable, ActivityTrackable

  belongs_to :user
  delegated_type :bucketable, types: %w[Collection FutureBucket MonthlyBucket], dependent: :destroy
  has_many :bullets, dependent: :nullify

  validates :name, presence: true
  validates :description, length: { maximum: 280 }, allow_blank: true

  normalizes :name, with: ->(name) { name.strip.downcase }

  after_update :record_updated_activity, if: :trackable_identity_changed?

  def searchable?
    !archived?
  end

  def search_name
    name
  end

  def search_body
    [name, description].compact.join(' ')
  end

  def show_path
    case bucketable
    when Collection
      Rails.application.routes.url_helpers.collection_path(bucketable)
    when MonthlyBucket
      Rails.application.routes.url_helpers.future_monthly_bucket_path(bucketable)
    when FutureBucket
      Rails.application.routes.url_helpers.future_path
    end
  end

  private

  def after_archive!
    record_activity!('archived', metadata: { 'bucketable_type' => bucketable_type })
  end

  def after_unarchive!
    record_activity!('unarchived', metadata: { 'bucketable_type' => bucketable_type })
  end

  def trackable_identity_changed?
    saved_change_to_name? || saved_change_to_colour? || saved_change_to_icon?
  end

  def record_updated_activity
    record_activity!('updated')
  end
end
