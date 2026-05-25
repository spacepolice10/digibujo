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
    if params[:year].present?
      Date.new(params[:year].to_i, params[:month].to_i, 1)
    else
      Date.current.beginning_of_month
    end
  rescue ArgumentError
    head :not_found
    nil
  end
end
