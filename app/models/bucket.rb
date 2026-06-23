# frozen_string_literal: true

class Bucket < ApplicationRecord
  include Bucket::Archivable, Colourable, Iconable, Pinnable, Bucket::Searchable, ActivityTrackable

  belongs_to :user
  delegated_type :bucketable, types: %w[Collection FutureBucket MonthlyBucket], dependent: :destroy
  has_many :bullets, dependent: :nullify

  validates :name, presence: true
  validates :description, length: { maximum: 280 }, allow_blank: true

  normalizes :name, with: ->(name) { name.strip.downcase }

  after_update :record_updated_activity

  private

  def record_updated_activity
    record_activity!('updated')
  end
end
