# frozen_string_literal: true

class DaylogsController < ApplicationController
  def show
    @selected_date = daylog_date_from_params or return
    @daylog = Current.user.daylog
    return unless @daylog

    @daylog_bucket = @daylog.bucket
    @bullets = set_page_and_extract_portion_from(
      @daylog.bullets.where(pops_on: @selected_date).active.order(created_at: :asc),
      per_page: [ 15, 30, 50 ]
    )
  end

  def create
    Current.user.ensure_daylog_bucket!
    redirect_to daylog_path
  end

  private

  def daylog_date_from_params
    if params[:date].present?
      Date.iso8601(params[:date].to_s)
    else
      Date.current
    end
  rescue ArgumentError
    head :not_found
    nil
  end
end
