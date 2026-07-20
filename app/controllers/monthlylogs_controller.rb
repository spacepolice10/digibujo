# frozen_string_literal: true

class MonthlylogsController < ApplicationController
  before_action :set_monthlylog, only: :show

  def current
    @monthlylog = Current.user.monthlylogs.find_by(
      period_from: Date.current.beginning_of_month
    )
    if @monthlylog
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
    @monthlylog = Current.user.monthlylogs.new
    @occupied_months = occupied_months
    @months = selectable_months
  end

  def create
    @monthlylog = Current.user.monthlylogs.new(period_from: period_from_param)
    if @monthlylog.period_from
      @monthlylog.build_bucket(
        user: Current.user,
        name: @monthlylog.period_from.strftime('%B %Y'),
        icon: 'calendar'
      )
    end

    if @monthlylog.save
      @monthlylog.bucket.record_activity!(
        'created',
        metadata: { 'bucketable_type' => @monthlylog.bucket.bucketable_type }
      )
      redirect_to monthlylog_path(@monthlylog), notice: 'Monthly spread created'
    else
      @occupied_months = occupied_months
      @months = selectable_months
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_monthlylog
    @monthlylog = Current.user.monthlylogs.find(params[:id])
  end

  def occupied_months
    Current.user.monthlylogs.pluck(:period_from)
  end

  def selectable_months
    start = Date.current.beginning_of_month - 1.month
    (0..12).map { |i| start + i.months }
  end

  def period_from_param
    raw = params.require(:monthlylog)[:period_from]
    return if raw.blank?

    Date.iso8601(raw.to_s).beginning_of_month
  rescue Date::Error, ArgumentError
    nil
  end

  def assign_data
    @bucket = @monthlylog.bucket
    @period_days = @monthlylog.period_days
    scoped = Current.user.bullets.where(bucket_id: @bucket.id).active
    @bullets_by_date = if @period_days
                         scoped.where(pops_on: @period_days).includes(:bulletable).group_by(&:pops_on)
                       else
                         {}
                       end
    @unplanned_bullets = scoped.where(pops_on: nil).order(created_at: :asc).includes(:bulletable)
  end
end
