# frozen_string_literal: true

class FuturesController < ApplicationController
  def show
    @future = find_future
    return unless @future

    @bullets = @future.bullets.active.includes(:bulletable).where(pops_on: nil).chronologically.last_page
    @more_bullets = @bullets.size == Bullet::Pageable::PAGE_SIZE
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

  private

  def find_future
    if params[:id].present?
      Current.user.futures.find(params[:id])
    else
      Current.user.futures.covering(Date.current).take
    end
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
