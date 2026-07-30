# frozen_string_literal: true

class Bucket < ApplicationRecord
  include Archivable, Colourable, Iconable, Pinnable, Bucket::Searchable, Bucket::NameMatching, ActivityTrackable

  belongs_to :user
  has_many :bullets, dependent: :destroy

  delegated_type :bucketable, types: %w[Collection Future Monthlylog Daylog Pending], dependent: :destroy

  validates :name, presence: true

  normalizes :name, with: ->(name) { name.strip.downcase }
end
