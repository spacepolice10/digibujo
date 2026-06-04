# frozen_string_literal: true

class MonthlylogsController < ApplicationController
  def show
    @anchor = monthlylog_anchor_from_params
    return unless @anchor

    @bullets = set_page_and_extract_portion_from(
      Current.user.bullets.monthlylog(@anchor),
      per_page: [5, 15, 30, 50]
    )
  end

  private

  def monthlylog_anchor_from_params
    if params[:date].present?
      Date.iso8601(params[:date].to_s).beginning_of_month
    else
      Date.current.beginning_of_month
    end
  rescue ArgumentError
    head :not_found
    nil
  end
end
