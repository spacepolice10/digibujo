# frozen_string_literal: true

class FutureBucketsController < ApplicationController
  def show
    future_bucket = Current.user.future_buckets.find(params[:id])
    @future = future_bucket.bucket
    @future_bucket = future_bucket
    @children = future_bucket.monthly_buckets.includes(:bucket)
  end

  def months
    future_bucket = Current.user.future_buckets.find(params[:id])
    last_child = future_bucket.monthly_buckets.maximum(:period_to)
    next_month = (last_child || Date.current.beginning_of_month) + 1.month

    @monthly_bucket = future_bucket.monthly_buckets.build(
      user: Current.user,
      period_from: next_month.beginning_of_month,
      period_to: next_month.end_of_month
    )
    @monthly_bucket.build_bucket(user: Current.user, name: next_month.strftime('%B %Y'))

    if @monthly_bucket.save
      redirect_to monthly_bucket_path(@monthly_bucket), notice: 'Month added'
    else
      redirect_to future_bucket_path(future_bucket), alert: 'Could not add month'
    end
  end
end
