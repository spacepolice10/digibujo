# frozen_string_literal: true

class FutureBucketsController < ApplicationController
  before_action :set_future_bucket
  def show
    @children = @future_bucket.monthly_buckets.includes(:bucket)
    @bullets = @future_bucket.bullets.order(created_at: :asc).includes(:bulletable)
  end

  def unplanned
    @bullets = @future_bucket.bullets.where(pops_on: nil).order(created_at: :asc).includes(:bulletable)
  end

  def monthly_grid
    @children = @future_bucket.monthly_buckets.includes(:bucket)
  end

  private

  def set_future_bucket
    @future_bucket = Current.user.future_buckets.find(params[:id])
  end
end
