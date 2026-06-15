# frozen_string_literal: true

class FuturesController < ApplicationController
  def show
    @future = Current.user.buckets
                     .where(bucketable_type: 'FutureBucket')
                     .first

    if @future
      @children = @future.bucketable.monthly_buckets.includes(:bucket)
      render :show
    else
      render :empty
    end
  end

  def create
    today = Date.current

    Bucket.transaction do
      future_bucket_record = FutureBucket.create!(user: Current.user)
      @future = Current.user.buckets.create!(
        bucketable: future_bucket_record,
        name: 'Future Log'
      )

      current_monthly = MonthlyBucket.current(Current.user)

      current_monthly ||= MonthlyBucket.create!(
        period_from: today.beginning_of_month,
        period_to: today.end_of_month
      ) { |mb| mb.build_bucket(user: Current.user, name: today.strftime('%B %Y')) }

      current_monthly.update!(future_bucket_id: future_bucket_record.id)
    end

    redirect_to future_path, notice: 'Future log created'
  end

  def months
    today = Date.current
    future = Current.user.buckets
                    .where(bucketable_type: 'FutureBucket')
                    .first

    if future
      future_bucket = future.bucketable
      last_child = future_bucket.monthly_buckets.maximum(:period_to)

      next_month = (last_child || today.beginning_of_month) + 1.month

      Bucket.transaction do
        MonthlyBucket.create!(
          user: Current.user,
          future_bucket_id: future_bucket.id,
          period_from: next_month.beginning_of_month,
          period_to: next_month.end_of_month
        ) { |mb| mb.build_bucket(user: Current.user, name: next_month.strftime('%B %Y')) }
      end
    end

    redirect_to future_path, notice: 'Month added'
  end
end
