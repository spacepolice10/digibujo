class Tag < ApplicationRecord
  belongs_to :user
  has_many :card_tags, dependent: :destroy
  has_many :cards, through: :card_tags

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }

  normalizes :name, with: ->(name) { name.strip.downcase }
end
