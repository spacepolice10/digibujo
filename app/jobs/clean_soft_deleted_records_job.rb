# frozen_string_literal: true

class CleanSoftDeletedRecordsJob < ApplicationJob
  def perform
    Bullet.expired_archived.destroy_all
    destroy_expired_archived_collections
  end

  private

  def destroy_expired_archived_collections
    Collection.expired_archived.find_each do |collection|
      collection.record_activity!(
        'destroyed',
        metadata: { 'name' => collection.name, 'colour' => collection.colour }
      )
      collection.destroy!
    end
  end
end
