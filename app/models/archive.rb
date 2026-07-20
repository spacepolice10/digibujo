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
    record_lifecycle_activity!('archived')
  end

  def record_unarchived_activity!
    record_lifecycle_activity!('unarchived')
  end

  def record_lifecycle_activity!(action)
    activities.create!(
      user: user || archivable.user,
      action: action,
      metadata: activity_metadata.merge('action' => action)
    )
  end

  def activity_metadata
    meta = {
      'name' => archivable.try(:name).to_s,
      'colour' => archivable.try(:colour),
      'archivable_type' => archivable_type
    }

    case archivable_type
    when 'Bullet'
      meta['pops_on'] = archivable.try(:pops_on)
      meta['bulletable_type'] = archivable.try(:bulletable_type)
    when 'Bucket'
      meta['bucketable_type'] = archivable.try(:bucketable_type)
    end

    meta.compact
  end

  def reindex_archivable
    return if archivable.blank? || archivable.destroyed?
    return unless archivable.respond_to?(:reindex)

    archivable.reindex
  end
end
