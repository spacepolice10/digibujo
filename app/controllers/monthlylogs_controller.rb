# frozen_string_literal: true

class MonthlylogsController < ApplicationController
  def show
    @monthlylog = find_monthlylog
    return unless @monthlylog

    @date = Date.current
    prepare_show
  end

  def monthlylog_date
    @monthlylog = find_monthlylog
    return unless @monthlylog

    @date = Date.iso8601(params[:date])

    @bullets = @monthlylog.bullets.where(pops_on: params[:date])
  end

  def new
    @monthlylog = Current.user.monthlylogs.new
    @occupied_months = occupied_months
    @months = selectable_months
  end

  def create
    @monthlylog = Current.user.monthlylogs.new(monthlylog_create_params)
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

  def find_monthlylog
    if params[:id].present?
      Current.user.monthlylogs.find(params[:id])
    else
      Current.user.monthlylogs.covering(Date.current).take
    end
  end

  def prepare_show
    @days = @monthlylog.spread_days
    scoped = @monthlylog.bullets.active.includes(:bulletable)
    grouped = scoped.where(pops_on: @days).group_by(&:pops_on)
    @bullets_by_date = @days.index_with { |day| grouped[day] || [] }
    @unplanned_bullets = scoped.where(pops_on: nil).order(created_at: :asc)
    @trackers = Current.user.trackers.where('start_date <= ?', @monthlylog.period_to).chronological.with_completions
    @mood_entities_by_date = CalendarDate.mood_entities_by_date(Current.user, @days)
    @pictures_by_date = CalendarDate.pictures_by_date(Current.user, @days)
  end

  def occupied_months
    Current.user.monthlylogs.pluck(:period_from)
  end

  def selectable_months
    start = Date.current.beginning_of_month - 1.month
    (0..12).map { |i| start + i.months }
  end

  def monthlylog_create_params
    raw = params.require(:monthlylog)
    period = begin
      Date.iso8601(raw[:period_from].to_s).beginning_of_month if raw[:period_from].present?
    rescue Date::Error, ArgumentError
      nil
    end

    {
      period_from: period
    }
  end
end
