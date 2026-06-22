# frozen_string_literal: true

class MonthlyBucketsController < ApplicationController
  before_action :set_monthly_bucket, only: :show

  def current
    @monthly_bucket = MonthlyBucket.current(Current.user)
    if @monthly_bucket
      assign_data
      render :show
    else
      render :empty
    end
  end

  def show
    assign_data
  end

  def new
    @monthly_bucket = MonthlyBucket.new(MonthlyBucket.default_period)
    @monthly_bucket.build_bucket(name: Date.current.strftime('%B %Y'))
    @occupied_months = occupied_months
  end

  def create
    month_date = Date.parse(monthly_bucket_params[:month])
    @monthly_bucket = Current.user.future_bucket!.monthly_buckets.build(
      user: Current.user,
      period_from: month_date.beginning_of_month,
      period_to: month_date.end_of_month
    )
    @monthly_bucket.build_bucket(
      user: Current.user,
      name: month_date.strftime("%B %Y"),
      icon: "calendar"
    )

    if @monthly_bucket.save
      @monthly_bucket.bucket.record_activity!(
        "created",
        metadata: { "bucketable_type" => @monthly_bucket.bucket.bucketable_type }
      )
      redirect_to future_monthly_bucket_path(@monthly_bucket), notice: 'Monthly spread created'
    else
      @occupied_months = occupied_months
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_monthly_bucket
    @monthly_bucket = Current.user.monthly_buckets.find(params[:id])
  end

  def occupied_months
    Current.user.monthly_buckets.pluck(:period_from)
  end

  def assign_data
    @bucket = @monthly_bucket.bucket
    @period_days = @monthly_bucket.period_days
    scoped = Current.user.bullets.where(bucket_id: @bucket.id, archived: false)
    @bullets_by_date = if @period_days
                         scoped.where(pops_on: @period_days).includes(:bulletable).group_by(&:pops_on)
                       else
                         {}
                       end
    @unplanned_bullets = scoped.where(pops_on: nil).chronological.includes(:bulletable)
    @recurrency_tracker = if @period_days
                            RecurrencyTracker.new(
                              user: Current.user,
                              from: @monthly_bucket.period_from,
                              to: @monthly_bucket.period_to
                            )
                          end
  end

  def monthly_bucket_params
    params.require(:monthly_bucket).permit(:month)
  end
end
