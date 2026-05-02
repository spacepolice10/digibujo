class TriageController < ApplicationController
  def show
    @selected_date = selected_date_param
    @bullets = Current.user.bullets.includes(:project).timeline.triage_on_date(@selected_date)
                      .where(archived: false)
  end

  private

  def selected_date_param
    return Date.current if params[:date].blank?

    Date.iso8601(params[:date])
  rescue ArgumentError
    Date.current
  end
end
