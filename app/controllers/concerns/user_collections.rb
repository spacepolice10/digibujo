# frozen_string_literal: true

module UserCollections
  extend ActiveSupport::Concern

  included do
    helper_method :user_collections
  end

  private

  def user_collections
    Collection.joins(:bucket).merge(Bucket.where(user_id: Current.user.id).active)
              .order('buckets.name')
  end

  def user_collections_matching(query)
    scope = user_collections
    sanitized = sanitized_collections_query(query)
    scope = scope.where('LOWER(buckets.name) LIKE ?', "#{sanitized}%") if sanitized.present?
    scope
  end

  def sanitized_collections_query(query)
    sanitized = ActiveRecord::Base.sanitize_sql_like(query.to_s.strip.downcase)
    sanitized.presence
  end
end
