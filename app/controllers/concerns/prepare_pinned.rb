# frozen_string_literal: true

module PreparePinned
  extend ActiveSupport::Concern

  private

  def pinned_bullets
    Current.user.bullets.includes(bucket: :bucketable).pinned.order(updated_at: :desc)
  end

  def pinned_buckets
    Current.user.buckets.includes(:bucketable).pinned.order(updated_at: :desc)
  end
end
