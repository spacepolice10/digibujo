class PinnedController < ApplicationController
  def index
    @bullets = Current.user.bullets.includes(bucket: :bucketable).pinned.order(updated_at: :desc)
    @buckets = Current.user.buckets.pinned
  end
end
