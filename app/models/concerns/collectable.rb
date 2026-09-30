# frozen_string_literal: true

module Collectable
  extend ActiveSupport::Concern

  # Moves the bullet off the timeline into a collection. There is no uncollect.
  def collect!(collection_id:)
    destination = user.collections.active.find(collection_id)
    return if self.collection_id == destination.id

    update!(collection: destination)
    record_activity!(
      'collected',
      metadata: { 'collection_id' => destination.id, 'collection_name' => destination.name }
    )
  end
end
