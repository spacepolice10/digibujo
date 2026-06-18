# frozen_string_literal: true

class Bucket < ApplicationRecord
  include Colourable, Iconable, Pinnable, Searchable

  belongs_to :user
  delegated_type :bucketable, types: %w[Collection Bundle FutureBucket MonthlyBucket], dependent: :destroy
  has_many :bullets, dependent: :nullify

  validates :name, presence: true

  normalizes :name, with: ->(name) { name.strip.downcase }

  def search_name
    name
  end

  def search_body
    name
  end
end
