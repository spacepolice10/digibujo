# frozen_string_literal: true

class FuturesController < ApplicationController
  before_action :set_future, only: %i[show unplanned monthly_grid]

  def show
    assign_grid
  end

  def new
    @future = Current.user.futures.new(period_from: Date.current.beginning_of_month)
  end

  def create
    @future = Current.user.futures.new(period_from: period_from_param)
    @future.build_bucket(
      user: Current.user,
      name: future_bucket_name(@future),
      icon: Onboarding::FUTURE_ICON,
      colour: Onboarding::FUTURE_COLOUR
    )

    if @future.save
      redirect_to future_path(@future), notice: 'Future log created'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def unplanned
    @bullets = @future.bullets.where(pops_on: nil).order(created_at: :asc).includes(:bulletable)
  end

  def monthly_grid
    assign_grid
  end

  private

  def set_future
    @future = Current.user.futures.find(params[:id])
  end

  def assign_grid
    @months = @future.spread_months
    scoped = @future.bullets.active.includes(:bulletable)
    grouped = scoped.where(pops_on: @months).includes(:bulletable).group_by(&:pops_on)
    @bullets_by_date = @months.index_with { |month| grouped[month] || [] }
    @unplanned_bullets = scoped.where(pops_on: nil).order(created_at: :asc)
  end

  def period_from_param
    raw = params.require(:future).require(:period_from)
    Date.iso8601(raw.to_s).beginning_of_month
  rescue Date::Error, ArgumentError
    nil
  end

  def future_bucket_name(future)
    return Onboarding::FUTURE_NAME if future.period_from.blank?

    last = future.period_from + 5.months
    "#{future.period_from.strftime('%b %Y')} – #{last.strftime('%b %Y')}"
  end
end
