# frozen_string_literal: true

class Bucket < ApplicationRecord
  include Colourable, Iconable, Pinnable, Periodable

  belongs_to :user
  delegated_type :bucketable, types: %w[Project Collection Monthlylog], dependent: :destroy
  has_many :bullets, dependent: :nullify, inverse_of: :bucket

  scope :monthlylog_buckets, -> { where(bucketable_type: "Monthlylog") }

  validates :name, presence: true

  validate :collection_name_unique_per_user, if: -> { bucketable_type == "Collection" }
  validate :monthlylog_period_unique, if: -> { monthlylog? && period_from.present? }

  before_validation :snap_monthlylog_period_from, if: :monthlylog?

  normalizes :name, with: ->(name) { name.strip.downcase }

  def monthlylog?
    bucketable_type == "Monthlylog"
  end

  private

  def snap_monthlylog_period_from
    self.period_from = period_from.beginning_of_month if period_from.present?
  end

  def collection_name_unique_per_user
    return unless user_id

    return unless user.buckets.where(bucketable_type: "Collection").where.not(id: id).exists?(name: name)

    errors.add(:name, "has already been taken")
  end

  def monthlylog_period_unique
    return unless user_id

    return unless user.buckets.monthlylog_buckets.where.not(id: id).exists?(period_from: period_from)

    errors.add(:base, "A monthly log already exists for #{period_from.strftime('%B %Y')}")
  end
end
