# frozen_string_literal: true

class BucketsController < ApplicationController
  def index
    @projects = Current.user.projects.first(8)
    @collections = Current.user.collections.first(8)
    @monthlylogs = Current.user.monthlylogs.first(8)
  end

  def show
    @bucket = Current.user.buckets.find(params[:id])
    @bullets = Current.user.bullets
      .where(bucket_id: @bucket.id)
      .includes(bucket: :bucketable)
      .order(updated_at: :desc)
  end
end
