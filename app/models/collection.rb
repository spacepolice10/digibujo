class Collection < ApplicationRecord
  include Colourable

  belongs_to :user
  has_many :cards, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }

  normalizes :name, with: ->(name) { name.strip.downcase }
end
