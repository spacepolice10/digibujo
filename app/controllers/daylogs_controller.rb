# frozen_string_literal: true

class DaylogsController < ApplicationController
  def show
    @selected_date = daylog_date_from_params
    return unless @selected_date

    @bullets = set_page_and_extract_portion_from(
      Current.user.bullets.dailylog(@selected_date),
      per_page: [15, 30, 50]
    )
  end

  private

  def daylog_date_from_params
    if params[:year].present?
      Date.new(params[:year].to_i, params[:month].to_i, params[:day].to_i)
    else
      Date.current
    end
  rescue ArgumentError
    head :not_found
    nil
  end
end
