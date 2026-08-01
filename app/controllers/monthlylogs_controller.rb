# frozen_string_literal: true

class MonthlylogsController < ApplicationController
  def show
    @monthlylog = find_monthlylog
    return unless @monthlylog

    @days = @monthlylog.spread_days
    @date = selected_date
    @bullet_counts_by_date = bullet_counts_by_date
    @pictures_by_date = CalendarDate.pictures_by_date(Current.user, @days)
  end

  def create
    @monthlylog = Monthlylog.provision!(Current.user)
    redirect_to monthlylog_path(@monthlylog), notice: 'Monthly spread created'
  end

  private

  def find_monthlylog
    if params[:id].present?
      Current.user.monthlylogs.find(params[:id])
    else
      Current.user.monthlylogs.covering(Date.current).take
    end
  end

  def selected_date
    today = Date.current
    return today if @days.include?(today)

    @days.first || today
  end

  def bullet_counts_by_date
    @monthlylog.bullets.active
               .where(pops_on: @days)
               .group(:pops_on)
               .count
  end
end
