# frozen_string_literal: true

class Archive < ApplicationRecord
  belongs_to :archivable, polymorphic: true
  belongs_to :user, optional: true
  has_many :activities, as: :subject

  validates :archivable_id, uniqueness: { scope: :archivable_type }

  after_create :record_archived_activity!
  after_create_commit :reindex_archivable
  before_destroy :record_unarchived_activity!, unless: :destroyed_by_association
  after_destroy_commit :reindex_archivable

  private

  def record_archived_activity!
    activities.create!(
      user: user || archivable.user,
      action: 'archived',
      metadata: { 'name' => archivable.try(:name).to_s }
    )
  end

  def record_unarchived_activity!
    activities.create!(
      user: user || archivable.user,
      action: 'unarchived',
      metadata: { 'name' => archivable.try(:name).to_s }
    )
  end

  def reindex_archivable
    return if archivable.blank? || archivable.destroyed?
    return unless archivable.respond_to?(:reindex)

    archivable.reindex
  end
end
