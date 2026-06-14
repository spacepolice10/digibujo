# frozen_string_literal: true

class PinnedEntity < ApplicationRecord
  belongs_to :user
  belongs_to :pinnable, polymorphic: true

  validates :pinnable_id, uniqueness: { scope: %i[user_id pinnable_type] }
end
