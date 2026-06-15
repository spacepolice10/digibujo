# frozen_string_literal: true

class BucketsController < ApplicationController
  include UserCollections

  COLLECTIONS_LIMIT = 8

  def index
    @projects = Current.user.projects.first(8)
    @collections = user_collections.limit(COLLECTIONS_LIMIT)

    @future = Current.user.buckets
                     .where(bucketable_type: 'FutureBucket')
                     .first

    @monthly_buckets = Current.user.monthly_buckets.first(8)
    @activities = Current.user.bullet_activities
                         .includes(:bullet)
                         .order(created_at: :desc)
                         .limit(6)
  end

  def show
    @bucket = Current.user.buckets.find(params[:id])
    @bullets = Current.user.bullets
                      .where(bucket_id: @bucket.id)
                      .includes(bucket: :bucketable)
                      .order(updated_at: :desc)
  end
end
