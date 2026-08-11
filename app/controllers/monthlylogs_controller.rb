# frozen_string_literal: true

class MonthlylogsController < ApplicationController
  def show
    @monthlylog = find_monthlylog
    return unless @monthlylog

    @days = @monthlylog.spread_days
    @date = selected_date
    @bullet_counts_by_date = bullet_counts_by_date
    @pictures_by_date = CalendarDate.pictures_by_date(Current.user, @days)
    @planned_bullets = @monthlylog.bullets.active.scheduled.limited_by_column(:pops_on, number: 5).includes(:bulletable)
    @days_with_bullets = @days.map { |day| [day, @planned_bullets.select { |bullet| bullet.pops_on == day }] }.to_h
    @unplanned_bullets = @monthlylog.bullets.active.unscheduled.includes(:bulletable)
    @days_to_show_in_inline_calendar = (@date..@date + 6.days).to_a
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
    return Date.current if @days.include?(Date.current)

    @days.first || Date.current
  end

  def bullet_counts_by_date
    @monthlylog.bullets.active
               .where(pops_on: @days)
               .group(:pops_on)
               .count
  end
end
