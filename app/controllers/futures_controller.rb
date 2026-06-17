# frozen_string_literal: true

class FuturesController < ApplicationController
  def show
    @future = Current.user.future_bucket!.bucket
    @children = @future.bucketable.monthly_buckets.includes(:bucket)
  end

  def months
    future_bucket = Current.user.future_bucket!
    last_child = future_bucket.monthly_buckets.maximum(:period_to)
    next_month = (last_child || Date.current.beginning_of_month) + 1.month

    @monthly_bucket = future_bucket.monthly_buckets.build(
      user: Current.user,
      period_from: next_month.beginning_of_month,
      period_to: next_month.end_of_month
    )
    @monthly_bucket.build_bucket(user: Current.user, name: next_month.strftime('%B %Y'))

    if @monthly_bucket.save
      redirect_to future_path, notice: 'Month added'
    else
      redirect_to future_path, alert: 'Could not add month'
    end
  end
end
