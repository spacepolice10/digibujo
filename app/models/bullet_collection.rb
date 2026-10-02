# frozen_string_literal: true

class BulletCollection < ApplicationRecord
  belongs_to :bullet
  belongs_to :collection

  validates :collection_id, uniqueness: { scope: :bullet_id }
end
