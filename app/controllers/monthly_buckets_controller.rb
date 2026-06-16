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
  end

  def create
    @monthly_bucket = MonthlyBucket.new(monthly_bucket_params.slice(:period_from, :period_to).merge(user: Current.user))
    @monthly_bucket.build_bucket(
      user: Current.user,
      name: monthly_bucket_params[:name],
      colour: monthly_bucket_params[:colour],
      icon: monthly_bucket_params[:icon]
    )

    if @monthly_bucket.save
      redirect_to monthly_bucket_path(@monthly_bucket), notice: 'Monthly spread created'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_monthly_bucket
    @monthly_bucket = MonthlyBucket.find(params[:id])
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
  end

  def monthly_bucket_params
    params.require(:monthly_bucket).permit(:name, :period_from, :period_to, :colour, :icon)
  end
end
