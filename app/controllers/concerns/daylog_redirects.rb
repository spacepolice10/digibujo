# frozen_string_literal: true

module DaylogRedirects
  extend ActiveSupport::Concern

  private

  def daylog_redirect_date
    return Date.current if params[:display_on].blank?

    Date.iso8601(params[:display_on].to_s)
  rescue ArgumentError
    Date.current
  end
end
