# frozen_string_literal: true

module Collectable
  extend ActiveSupport::Concern

  # Tags the bullet with a collection. The bullet stays on the timeline.
  # Adding the same collection twice is a no-op. There is no uncollect.
  def collect!(collection_id:)
    destination = user.collections.active.find(collection_id)
    return if collections.exists?(destination.id)

    collections << destination
    record_activity!(
      'collected',
      metadata: { 'collection_id' => destination.id, 'collection_name' => destination.name }
    )
    reindex
  end
end
