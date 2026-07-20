# frozen_string_literal: true

class CleanSoftDeletedRecordsJob < ApplicationJob
  def perform
    # TODO: Bullet.auto_archivable — grace window and completed archives_on not implemented yet
    Bullet.expired_archived.destroy_all
    destroy_expired_archived_buckets
  end

  private

  def destroy_expired_archived_buckets
    Bucket.expired_archived.find_each do |bucket|
      bucket.record_activity!(
        'destroyed',
        metadata: {
          'bucketable_type' => bucket.bucketable_type,
          'name' => bucket.name,
          'colour' => bucket.colour
        }
      )
      bucket.destroy!
    end
  end
end
