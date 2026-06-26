# frozen_string_literal: true

class FutureBucketsController < ApplicationController
  def show
    future_bucket = Current.user.future_buckets.find(params[:id])
    @future = future_bucket.bucket
    @future_bucket = future_bucket
    @children = future_bucket.monthly_buckets.includes(:bucket)
  end
end
