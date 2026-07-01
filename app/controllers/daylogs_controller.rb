# frozen_string_literal: true

class DaylogsController < ApplicationController
  def show
    @selected_date = daylog_date_from_params
    return unless @selected_date

    @bullets = set_page_and_extract_portion_from(
      Current.user.bullets.where(pops_on: @selected_date).active,
      per_page: [15, 30, 50]
    )
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
