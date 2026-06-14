# frozen_string_literal: true

module PreparePinned
  extend ActiveSupport::Concern

  private

  def pinned_bullets
    Current.user.pinned_entities.where(pinnable_type: "Bullet")
            .includes(pinnable: { bucket: :bucketable })
            .order(created_at: :desc)
            .map(&:pinnable)
  end

  def pinned_buckets
    Current.user.pinned_entities.where(pinnable_type: "Bucket")
            .includes(pinnable: :bucketable)
            .order(created_at: :desc)
            .map(&:pinnable)
  end
end
