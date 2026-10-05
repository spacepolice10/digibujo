# frozen_string_literal: true

class Archive < ApplicationRecord
  belongs_to :archivable, polymorphic: true
  belongs_to :user, optional: true

  validates :archivable_id, uniqueness: { scope: :archivable_type }

  after_create_commit :reindex_archivable
  after_destroy_commit :reindex_archivable

  private

  def reindex_archivable
    return if archivable.blank? || archivable.destroyed?
    return unless archivable.respond_to?(:reindex)

    archivable.reindex
  end
end
