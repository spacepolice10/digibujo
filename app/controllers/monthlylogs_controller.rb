# frozen_string_literal: true

class MonthlylogsController < ApplicationController
  before_action :set_monthlylog, only: :show

  def current
    @monthlylog = Monthlylog.current(Current.user)
    if @monthlylog
      assign_spread_data
      render :show
    else
      render :empty
    end
  end

  def show
    assign_spread_data
  end

  def new
    @monthlylog = Monthlylog.new
    @bucket = @monthlylog.build_bucket(
      name: Date.current.strftime("%B %Y"),
      **Bucket.monthlylog_period
    )
  end

  def create
    @monthlylog = Monthlylog.new
    @bucket = Current.user.buckets.build(bucketable: @monthlylog, **monthlylog_bucket_attrs)

    ActiveRecord::Base.transaction do
      @monthlylog.save!
      @bucket.save!
    end

    redirect_to monthlylog_path(@monthlylog), notice: "Monthly log created"
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private

  def set_monthlylog
    @monthlylog = Current.user.monthlylogs.find(params[:id])
  end

  def assign_spread_data
    @bucket = @monthlylog.bucket
    @period_days = @monthlylog.period_days
    scoped = Current.user.bullets.where(bucket_id: @bucket.id, archived: false)
    @bullets_by_date = if @period_days
      scoped.where(pops_on: @period_days).includes(:bulletable).group_by(&:pops_on)
    else
      {}
    end
    @unplanned_bullets = scoped.where(pops_on: nil).chronological.includes(:bulletable)
  end

  def monthlylog_params
    params.require(:monthlylog).permit(:name, :period_from, :period_to, :colour, :icon)
  end

  def monthlylog_bucket_attrs
    monthlylog_params.to_h.symbolize_keys
  end
end
