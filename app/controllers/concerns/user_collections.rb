# frozen_string_literal: true

module UserCollections
  extend ActiveSupport::Concern

  private

  def user_collections
    Collection.joins(:bucket).where(buckets: { user_id: Current.user.id }).order('buckets.name')
  end
end
