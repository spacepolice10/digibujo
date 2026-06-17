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

    @future_bucket = FutureBucket.new(user: Current.user)
    @future_bucket.build_bucket(user: Current.user, name: 'Future Log')

    if @future_bucket.save
      link_current_monthly_to(@future_bucket, today)
      redirect_to future_path, notice: 'Future log created'
    else
      render :empty, status: :unprocessable_entity
    end
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

      @monthly_bucket = MonthlyBucket.new(
        user: Current.user,
        future_bucket: future_bucket,
        period_from: next_month.beginning_of_month,
        period_to: next_month.end_of_month
      )
      @monthly_bucket.build_bucket(user: Current.user, name: next_month.strftime('%B %Y'))

      if @monthly_bucket.save
        redirect_to future_path, notice: 'Month added'
      else
        redirect_to future_path, alert: 'Could not add month'
      end
    else
      redirect_to future_path, alert: 'No future log found'
    end
  end

  private

  def link_current_monthly_to(future_bucket, today)
    current_monthly = MonthlyBucket.current(Current.user)

    current_monthly ||= begin
      mb = MonthlyBucket.new(
        user: Current.user,
        period_from: today.beginning_of_month,
        period_to: today.end_of_month
      )
      mb.build_bucket(user: Current.user, name: today.strftime('%B %Y'))
      mb.save!
      mb
    end

    current_monthly.update!(future_bucket_id: future_bucket.id)
  rescue ActiveRecord::RecordInvalid
    # If current monthly can't be created, still allow future log creation
    nil
  end
end
