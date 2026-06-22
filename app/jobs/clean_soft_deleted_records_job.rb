# frozen_string_literal: true

class CleanSoftDeletedRecordsJob < ApplicationJob
  def perform
    # TODO: Bullet.auto_archivable — grace window and completed archives_on not implemented yet
    Bullet.expired_archived.destroy_all
    Bucket.expired_archived.destroy_all
  end
end
