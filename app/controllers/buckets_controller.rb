# frozen_string_literal: true

# Shows an individual bucket's bullets for footer popovers.
class BucketsController < ApplicationController
  def show
    @bucket = Current.user.buckets.find(params[:id])
    @bullets = Current.user.bullets
                      .where(bucket_id: @bucket.id)
                      .includes(bucket: :bucketable)
                      .order(updated_at: :desc)
  end
end
