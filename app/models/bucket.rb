# frozen_string_literal: true

class Bucket < ApplicationRecord
  include Colourable, Iconable

  belongs_to :user
  delegated_type :bucketable, types: %w[Project Collection], dependent: :destroy
  has_many :bullets, dependent: :nullify, inverse_of: :bucket

  validates :name, presence: true

  normalizes :name, with: ->(name) { name.strip.downcase }
end
