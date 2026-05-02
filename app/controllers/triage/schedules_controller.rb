class Triage::SchedulesController < ApplicationController
  before_action :set_bullet

  def create
    @bullet.schedule!(scheduled_on: params[:scheduled_on])

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to triage_path(date: selected_date_param.iso8601) }
    end
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.triage_on_date(selected_date_param).find(params[:bullet_bullet_id] || params[:bullet_id])
  end

  def selected_date_param
    return Date.current if params[:date].blank?

    Date.iso8601(params[:date])
  rescue ArgumentError
    Date.current
  end

end
