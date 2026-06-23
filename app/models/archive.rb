# frozen_string_literal: true

class Archive < ApplicationRecord
  belongs_to :archivable, polymorphic: true
  belongs_to :user, optional: true

  validates :archivable_id, uniqueness: { scope: :archivable_type }
end
