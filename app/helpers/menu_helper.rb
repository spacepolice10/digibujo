# frozen_string_literal: true

module MenuHelper
  COLLECTION_LIMIT = 8

  def menu_collections
    Current.user.collections.first(COLLECTION_LIMIT)
  end
end
