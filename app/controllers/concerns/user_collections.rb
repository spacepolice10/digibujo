# frozen_string_literal: true

module UserCollections
  extend ActiveSupport::Concern

  included do
    helper_method :user_collections
  end

  private

  def user_collections
    Collection.joins(:bucket)
              .where(buckets: { user_id: Current.user.id, archived: false })
              .order('buckets.name')
  end
end
