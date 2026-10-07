# frozen_string_literal: true

module Collectable
  extend ActiveSupport::Concern

  def collect!(collection_id:)
    destination = user.collections.find(collection_id)
    return if collections.exists?(destination.id)

    collections << destination
  end
end
