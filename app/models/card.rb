class Card < ApplicationRecord
  belongs_to :user
  delegated_type :cardable, types: %w[Task Note], dependent: :destroy

  has_rich_text :content
end
